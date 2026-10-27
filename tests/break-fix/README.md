# Break-fix tests

Each test breaks one of the landing zone's rules on purpose, to prove the control works.
Results: [evidence 03](../../docs/evidence/03-policy-break-fix.txt) (test 2) and
[evidence 07](../../docs/evidence/07-break-fix-admission-and-runtime.txt) (tests 1 and 3).

| File | Test | Expected |
|---|---|---|
| `00-namespace.yaml` | Namespace for the tests, without Pod Security labels | Created |
| `01-untrusted-root-pod.yaml` | 1: Docker Hub image, root, privileged, privilege escalation, writable filesystem | Denied by Azure Policy (Gatekeeper); in `notes`, denied by Pod Security Admission |
| `03-defender-alert-pod.yaml` | 3b: fully compliant pod that runs Defender's harmless test binary | Admitted, then a Defender for Containers alert |

## Run

```bash
kubectl apply -f tests/break-fix/00-namespace.yaml
kubectl apply -n breakfix -f tests/break-fix/01-untrusted-root-pod.yaml   # test 1
kubectl apply -n notes    -f tests/break-fix/01-untrusted-root-pod.yaml   # test 1b

ACR_SERVER=$(terraform -chdir=infra/terraform/envs/dev output -raw acr_login_server)
sed "s|ACR_LOGIN_SERVER|$ACR_SERVER|" tests/break-fix/03-defender-alert-pod.yaml | kubectl apply -n breakfix -f -
kubectl exec -n breakfix defender-alert-test -- sh -c 'cp /bin/echo /tmp/asc_alerttest_662jfi039n && /tmp/asc_alerttest_662jfi039n testing eicar pipe'
kubectl get pods --namespace=asc-alerttest-662jfi039n                     # control-plane test alert
```

Test 3a imports an outdated image into the registry for Defender to scan:
`az acr import -n <acr-name> --source docker.io/library/nginx:1.14.2 --image breakfix/nginx:1.14.2`

## Clean up

```bash
kubectl delete namespace breakfix
az acr repository delete -n <acr-name> --repository breakfix/nginx --yes
az acr repository delete -n <acr-name> --repository breakfix/ubuntu --yes
```
