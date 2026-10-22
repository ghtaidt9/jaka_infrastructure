kubectl get pods -n dev
kubectl describe pod <pod> -n dev          # check the Events section at the bottom
kubectl logs <pod> -n dev --previous       # logs from the previous (crashed) run
kubectl exec -it <pod> -n dev -- sh
kubectl get events -n dev --sort-by=.lastTimestamp
