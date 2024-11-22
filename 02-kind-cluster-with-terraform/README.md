# Clúster Kind con Nginx Ingress Controller

## Estructura del Proyecto
```
.
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── ingress.tf
└── kubernetes/
    └── test-app.yaml
```

## Despliegue del Clúster

```bash
cd terraform
terraform init
terraform plan
terraform apply -auto-approve
```

## Despliegue de la Aplicación de Prueba

```bash
cd ../kubernetes
kubectl apply -f test-app.yaml

# Verificar despliegue
kubectl get pods
kubectl get ingress
kubectl get services

# Probar el acceso
curl localhost/hello
```

## Verificación de Componentes

```bash
# Estado del Ingress Controller
kubectl get pods -n ingress-nginx

# Logs del Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller

# Estado del Ingress
kubectl describe ingress hello-ingress
```

## Limpieza
```bash
# Eliminar aplicación
kubectl delete -f test-app.yaml

# Eliminar infraestructura
cd ../terraform
terraform destroy -auto-approve
```