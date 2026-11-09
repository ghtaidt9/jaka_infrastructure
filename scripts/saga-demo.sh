#!/usr/bin/env bash
# scripts/saga-demo.sh - prove the 4 Saga branches end to end on kind
#
# Needs the gateway port-forward from cluster-up.sh running in another terminal:
#   svc=$(kubectl get svc -n envoy-gateway-system -l gateway.envoyproxy.io/owning-gateway-name=web -o name)
#   kubectl port-forward -n envoy-gateway-system $svc 8090:80
#
# Usage:
#   ./scripts/saga-demo.sh              # branches 1-3 (~1 minute)
#   ./scripts/saga-demo.sh --timeout    # also branch 4: timeout + late payment refund (~8 minutes)
set -euo pipefail

base=${BASE_URL:-http://localhost:8090}
sku=TEST-001
failures=0

order_status() {   # $1 = order id → "STATUS reason"
    curl -sf "$base/api/orders" | jq -r --argjson id "$1" '.[] | select(.id == $id) | "\(.status) \(.cancelReason // "")"'
}

stock() {          # available/reserved of $sku
    curl -sf "$base/api/inventory/products/$sku" | jq -r '"\(.available)/\(.reserved)"'
}

reservation() {    # $1 = order id → reservation status, or "none"
    curl -sf "$base/api/inventory/reservations" | jq -r --argjson id "$1" \
        '[.[] | select(.orderId == $id) | .status] | first // "none"'
}

payment() {        # $1 = order id → payment status, or "none"
    curl -sf "$base/api/payments" | jq -r --argjson id "$1" \
        '[.[] | select(.orderId == $id) | .status] | first // "none"'
}

create_order() {   # $1 = customer, $2 = amount, $3 = sku → order id
    curl -sf -X POST "$base/api/orders" -H 'Content-Type: application/json' \
        -d "{\"customerName\":\"$1\",\"totalAmount\":$2,\"currency\":\"USD\",\"productSku\":\"$3\",\"quantity\":1}" \
        | jq -r '.id'
}

wait_status() {    # $1 = order id, $2 = expected status, $3 = timeout seconds
    local deadline=$((SECONDS + $3)) s
    while ((SECONDS < deadline)); do
        s=$(order_status "$1")
        [[ $s == "$2"* ]] && { echo "$s"; return 0; }
        sleep 3
    done
    echo "$(order_status "$1") (gave up after $3s)"
    return 1
}

check() {          # $1 = label, $2 = actual, $3 = expected
    if [[ $2 == "$3" ]]; then
        printf '   ✅ %-28s %s\n' "$1" "$2"
    else
        printf '   ❌ %-28s %s (expected %s)\n' "$1" "$2" "$3"
        failures=$((failures + 1))
    fi
}

curl -sf -o /dev/null "$base/api/orders/actuator/health" \
    || { echo "gateway not reachable at $base - start the port-forward first" >&2; exit 1; }

# --- 1. happy path --------------------------------------------------------------------------
echo "1) Success: stock available, payment approved"
before=$(stock)
id=$(create_order "Alice" 100 "$sku")
status=$(wait_status "$id" CONFIRMED 60 || true)
check "order $id"            "${status%% *}" CONFIRMED
check "reservation"          "$(reservation "$id")" COMMITTED
check "payment"              "$(payment "$id")" COMPLETED
check "stock before → after" "$before → $(stock)" "$before → $(( ${before%/*} - 1 ))/${before#*/}"

# --- 2. out of stock ------------------------------------------------------------------------
echo "2) Out of stock: inventory rejects, nothing is charged"
id=$(create_order "Bob" 100 SOLD-OUT-001)
status=$(wait_status "$id" CANCELLED 60 || true)
check "order $id"            "$status" "CANCELLED Insufficient stock"
check "reservation"          "$(reservation "$id")" none
check "payment"              "$(payment "$id")" none

# --- 3. payment declined --------------------------------------------------------------------
echo "3) Payment declined (amount > 1000): stock is put back"
before=$(stock)
id=$(create_order "Carol" 1500 "$sku")
status=$(wait_status "$id" CANCELLED 60 || true)
check "order $id"            "$status" "CANCELLED CARD_DECLINED"
sleep 3   # InventoryReleased is written after PaymentFailed reaches inventory
check "reservation"          "$(reservation "$id")" RELEASED
check "payment"              "$(payment "$id")" FAILED
check "stock before → after" "$before → $(stock)" "$before → $before"

# --- 4. timeout + late payment --------------------------------------------------------------
if [[ ${1:-} == --timeout ]]; then
    echo "4) Timeout: payment-service down > 5 min, then comes back late"
    replicas=$(kubectl get deploy payment-service -n dev -o jsonpath='{.spec.replicas}')
    kubectl scale deploy payment-service -n dev --replicas=0 >/dev/null
    kubectl rollout status deploy/payment-service -n dev --timeout=2m >/dev/null
    before=$(stock)
    id=$(create_order "Dave" 100 "$sku")
    echo "   order $id created, waiting for OrderTimeoutJob (5 min + up to 60 s scan delay)..."
    status=$(wait_status "$id" CANCELLED 480 || true)
    check "order $id"            "$status" "CANCELLED PAYMENT_TIMEOUT"
    sleep 5
    check "reservation"          "$(reservation "$id")" RELEASED
    check "stock before → after" "$before → $(stock)" "$before → $before"

    echo "   payment-service back: it charges the stale InventoryReserved, order-service asks for a refund"
    kubectl scale deploy payment-service -n dev --replicas="$replicas" >/dev/null
    kubectl rollout status deploy/payment-service -n dev --timeout=5m >/dev/null
    deadline=$((SECONDS + 120)); p=none
    while ((SECONDS < deadline)) && [[ $p != REFUNDED ]]; do sleep 5; p=$(payment "$id"); done
    check "payment"              "$p" REFUNDED
    check "order still"          "$(order_status "$id")" "CANCELLED PAYMENT_TIMEOUT"
fi

echo
if ((failures == 0)); then echo "All checks passed"; else echo "$failures check(s) failed"; exit 1; fi
