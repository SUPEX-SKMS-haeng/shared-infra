# 1. Namespace 생성
```
kubectl create dev
```

# 2. ACR Secret 생성
```
# image pull용 Secret - DockerServer, User, Password, email 확인

kubectl -n dev create secret docker-registry azure-container-registry \
  --docker-server=<Docker-Server> \
  --docker-username=<User> \
  --docker-password=<PW> \
  --docker-email=<Email>
```

# 3. SA 및 Role 생성
```
kubectl -n dev create -f ./kubernetes/etc/serviceaccount.yml
```

# 4. PVC 생성
Storage 준비중
```
kubectl -n dev create -f ./kubernetes/pvc/common-pvc.yml
```

# 5. Secret 생성
```
kubectl -n dev create -f ./kubernetes/etc/common-secret.yml
```

# 6. ConfigMap 생성
```
kubectl -n dev create -f ./kubernetes/etc/infra-config.yml
kubectl -n dev create -f ./kubernetes/etc/common-config.yml

kubectl -n dev create -f ./kubernetes/configmap/gateway-conf.yml
kubectl -n dev create -f ./kubernetes/configmap/gateway-dynamic-conf.yml

kubectl -n dev create -f ./kubernetes/configmap/front-node-server.yml
```

# 7. Application 생성
```
kubectl -n dev create -f ./kubernetes/deployment/auth.yml
kubectl -n dev create -f ./kubernetes/service/auth.yml

kubectl -n dev create -f ./kubernetes/deployment/chat.yml
kubectl -n dev create -f ./kubernetes/service/chat.yml

kubectl -n dev create -f ./kubernetes/deployment/llm-gateway.yml
kubectl -n dev create -f ./kubernetes/service/llm-gateway.yml

kubectl -n dev create -f ./kubernetes/deployment/gateway.yml
kubectl -n dev create -f ./kubernetes/service/gateway.yml

kubectl -n dev create -f ./kubernetes/deployment/front-admin.yml
kubectl -n dev create -f ./kubernetes/service/front-admin.yml
kubectl -n dev create -f ./kubernetes/deployment/front-chat.yml
kubectl -n dev create -f ./kubernetes/service/front-chat.yml
```