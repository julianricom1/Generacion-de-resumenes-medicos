# =========
# Variables
# =========
CURDIR            ?= $(shell pwd)
TERRAFORM_ENV     ?= student
REGION            ?= us-east-1
TF_BACKEND_BUCKET ?= infrastructura-maia-g8
ACCOUNT_ID        := $(shell aws sts get-caller-identity --query Account --output text)

# ================
# Bucket S3
# ================
.PHONY: tf-backend-bucket tf-backend-bucket-delete
tf-backend-bucket:
	@echo ">> Verificando bucket S3: $(TF_BACKEND_BUCKET) en $(REGION)"
	@if aws s3api head-bucket --bucket $(TF_BACKEND_BUCKET) 2>/dev/null; then \
	  echo "   Bucket ya existe."; \
	else \
	  if [ "$(REGION)" = "us-east-1" ]; then \
	    aws s3api create-bucket --bucket $(TF_BACKEND_BUCKET) --region $(REGION); \
	  else \
	    aws s3api create-bucket --bucket $(TF_BACKEND_BUCKET) --region $(REGION) \
	      --create-bucket-configuration LocationConstraint=$(REGION); \
	  fi; \
	  aws s3api put-bucket-versioning \
	    --bucket $(TF_BACKEND_BUCKET) --versioning-configuration Status=Enabled; \
	  aws s3api put-bucket-encryption \
	    --bucket $(TF_BACKEND_BUCKET) \
	    --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'; \
	fi

tf-backend-bucket-delete:
	@echo ">> Eliminando objetos versionados en s3://$(TF_BACKEND_BUCKET)"
	@aws s3api list-object-versions --bucket $(TF_BACKEND_BUCKET) --output json | \
	  jq -r '.Versions[]?, .DeleteMarkers[]? | {Key:.Key, VersionId:.VersionId} | @json' | \
	  while read -r obj; do \
	    key=$$(echo $$obj | jq -r .Key); \
	    vid=$$(echo $$obj | jq -r .VersionId); \
	    aws s3api delete-object --bucket $(TF_BACKEND_BUCKET) --key "$$key" --version-id "$$vid" >/dev/null; \
	  done || true
	@echo ">> Eliminando bucket s3://$(TF_BACKEND_BUCKET)"
	@aws s3api delete-bucket --bucket $(TF_BACKEND_BUCKET) --region $(REGION) || true

# =========================
# Terraform Stack (genérico)
# =========================
.PHONY: tfinit tfplan tfapply tfdestroy
tfinit:
	terraform -chdir="$(shell pwd)/terraform/stacks/${STACK}" init -reconfigure \
	  -backend-config="$(shell pwd)/terraform/environments/${TERRAFORM_ENV}/${STACK}/backend.tfvars"

tfplan:
	terraform -chdir="$(shell pwd)/terraform/stacks/${STACK}" plan \
	  -var-file="$(shell pwd)/terraform/environments/${TERRAFORM_ENV}/${STACK}/terraform.tfvars" \
	  -out="$(STACK).tfplan"

tfapply:
	terraform -chdir="$(shell pwd)/terraform/stacks/${STACK}" apply "$(STACK).tfplan"

tfdestroy:
	terraform -chdir="$(shell pwd)/terraform/stacks/${STACK}" destroy -auto-approve \
	  -var-file="$(shell pwd)/terraform/environments/${TERRAFORM_ENV}/${STACK}/terraform.tfvars"

# =========================
# Registry (ECR)
# =========================
.PHONY: registry-init registry-plan registry-apply registry-destroy
registry-init:
	$(MAKE) tf-backend-bucket REGION=$(REGION) TF_BACKEND_BUCKET=$(TF_BACKEND_BUCKET)
	$(MAKE) tfinit STACK=registry TERRAFORM_ENV=$(TERRAFORM_ENV)

registry-plan:
	$(MAKE) tfplan STACK=registry TERRAFORM_ENV=$(TERRAFORM_ENV)

registry-apply:
	$(MAKE) tfapply STACK=registry TERRAFORM_ENV=$(TERRAFORM_ENV)

registry-destroy:
	$(MAKE) tfdestroy STACK=registry TERRAFORM_ENV=$(TERRAFORM_ENV)

# =========================
# Docker Image
# =========================
.PHONY: build-image ecr-login push-image
build-image:
	docker build --rm --platform linux/amd64 --no-cache -f metricas/Dockerfile -t metricas-api:latest ./metricas

ecr-login:
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com"

push-image:
	docker tag "metricas-api:latest" "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/metricas-api:latest"
	docker push "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/metricas-api:latest"

# =========================
# Terraform Stacks
# =========================
.PHONY: vpc-init vpc-plan vpc-apply vpc-destroy \
        ecs-init ecs-plan ecs-apply ecs-destroy \
        alb-init alb-plan alb-apply alb-destroy \
        app-init app-plan app-apply app-destroy

# VPC
vpc-init:
	$(MAKE) tfinit STACK=vpc TERRAFORM_ENV=$(TERRAFORM_ENV)
vpc-plan:
	@if [ ! -d "terraform/stacks/vpc/.terraform" ]; then $(MAKE) vpc-init; fi
	$(MAKE) tfplan STACK=vpc TERRAFORM_ENV=$(TERRAFORM_ENV)
vpc-apply:
	@if [ ! -d "terraform/stacks/vpc/.terraform" ]; then $(MAKE) vpc-init; fi
	@if [ ! -f "vpc.tfplan" ]; then $(MAKE) vpc-plan; fi
	$(MAKE) tfapply STACK=vpc TERRAFORM_ENV=$(TERRAFORM_ENV)
vpc-destroy:
	@if [ ! -d "terraform/stacks/vpc/.terraform" ]; then $(MAKE) vpc-init; fi
	$(MAKE) tfdestroy STACK=vpc TERRAFORM_ENV=$(TERRAFORM_ENV)

# ECS
ecs-init:
	$(MAKE) tfinit STACK=ecs TERRAFORM_ENV=$(TERRAFORM_ENV)
ecs-plan:
	@if [ ! -d "terraform/stacks/ecs/.terraform" ]; then $(MAKE) ecs-init; fi
	$(MAKE) tfplan STACK=ecs TERRAFORM_ENV=$(TERRAFORM_ENV)
ecs-apply:
	@if [ ! -d "terraform/stacks/ecs/.terraform" ]; then $(MAKE) ecs-init; fi
	@if [ ! -f "ecs.tfplan" ]; then $(MAKE) ecs-plan; fi
	$(MAKE) tfapply STACK=ecs TERRAFORM_ENV=$(TERRAFORM_ENV)
ecs-destroy:
	@if [ ! -d "terraform/stacks/ecs/.terraform" ]; then $(MAKE) ecs-init; fi
	$(MAKE) tfdestroy STACK=ecs TERRAFORM_ENV=$(TERRAFORM_ENV)

# ALB
alb-init:
	$(MAKE) tfinit STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)
alb-plan:
	@if [ ! -d "terraform/stacks/alb/.terraform" ]; then $(MAKE) alb-init; fi
	$(MAKE) tfplan STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)
alb-apply:
	@if [ ! -d "terraform/stacks/alb/.terraform" ]; then $(MAKE) alb-init; fi
	@if [ ! -f "alb.tfplan" ]; then $(MAKE) alb-plan; fi
	$(MAKE) tfapply STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)
alb-destroy:
	@if [ ! -d "terraform/stacks/alb/.terraform" ]; then $(MAKE) alb-init; fi
	$(MAKE) tfdestroy STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)

# App
app-init:
	$(MAKE) tfinit STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)
app-plan:
	@if [ ! -d "terraform/stacks/app/.terraform" ]; then $(MAKE) app-init; fi
	$(MAKE) tfplan STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)
app-apply:
	@if [ ! -d "terraform/stacks/app/.terraform" ]; then $(MAKE) app-init; fi
	@if [ ! -f "app.tfplan" ]; then $(MAKE) app-plan; fi
	$(MAKE) tfapply STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)
app-destroy:
	@if [ ! -d "terraform/stacks/app/.terraform" ]; then $(MAKE) app-init; fi
	$(MAKE) tfdestroy STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)

# =========================
# Orquestación
# =========================
.PHONY: deploy-infra deploy-vpc deploy-app destroy-app
deploy-infra:
	$(MAKE) registry-init
	$(MAKE) registry-plan
	$(MAKE) registry-apply

deploy-vpc:
	$(MAKE) vpc-init
	$(MAKE) vpc-plan
	$(MAKE) vpc-apply

deploy-app:
	$(MAKE) ecs-init
	$(MAKE) ecs-plan
	$(MAKE) ecs-apply
	$(MAKE) alb-init
	$(MAKE) alb-plan
	$(MAKE) alb-apply
	$(MAKE) app-init
	$(MAKE) app-plan
	$(MAKE) app-apply

destroy-app:
	$(MAKE) app-destroy
	$(MAKE) alb-destroy
	$(MAKE) ecs-destroy

# =========================
# Utilidades
# =========================
.PHONY: alb-dns purge-alb-enis service-status
alb-dns:
	@set -e; \
	if terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw alb_dns >/dev/null 2>&1; then \
	  DNS=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw alb_dns); \
	else \
	  ALB_ARN=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw alb_arn); \
	  DNS=$$(aws elbv2 describe-load-balancers --load-balancer-arns $$ALB_ARN --query 'LoadBalancers[0].DNSName' --output text); \
	fi; \
	printf "\nALB URL: http://%s/\n\n" "$$DNS"

service-status:
	@echo ">> Estado del servicio ECS..."
	@aws ecs describe-services \
	  --cluster metricas-cluster \
	  --services metricas-svc \
	  --region $(REGION) \
	  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Events:events[0:3]}' \
	  --output json | jq '.' || echo "Error al obtener el estado del servicio"

purge-alb-enis:
	@echo ">> Buscando ENIs ligados al SG del ALB..."
	@ALB_SG=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw alb_sg_id 2>/dev/null || true); \
	if [ -z "$$ALB_SG" ]; then echo "   No hay alb_sg_id en outputs (ALB ya destruido?)."; exit 0; fi; \
	ENIS=$$(aws ec2 describe-network-interfaces --filters Name=group-id,Values=$$ALB_SG --query 'NetworkInterfaces[*].NetworkInterfaceId' --output text); \
	if [ -n "$$ENIS" ]; then \
	  echo "   ENIs encontradas: $$ENIS"; \
	  for eni in $$ENIS; do \
	    ATT=$$(aws ec2 describe-network-interfaces --network-interface-ids $$eni --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text 2>/dev/null || true); \
	    if [ "$$ATT" != "None" ] && [ -n "$$ATT" ]; then \
	      echo "   Detaching $$eni ($$ATT)..."; \
	      aws ec2 detach-network-interface --attachment-id $$ATT || true; \
	    fi; \
	    echo "   Esperando a que $$eni quede 'available'..."; \
	    for i in 1 2 3 4 5 6 7 8 9 10; do \
	      S=$$(aws ec2 describe-network-interfaces --network-interface-ids $$eni --query 'NetworkInterfaces[0].Status' --output text 2>/dev/null || true); \
	      if [ "$$S" = "available" ]; then break; fi; \
	      sleep 3; \
	    done; \
	    echo "   Eliminando ENI $$eni..."; \
	    aws ec2 delete-network-interface --network-interface-id $$eni || true; \
	  done; \
	else \
	  echo "   No hay ENIs asociadas."; \
	fi

# =========================
# Shortcuts Principales
# =========================
.PHONY: startall destroyall redeploy-metrics stop-metrics restore-metrics
startall:
	$(MAKE) deploy-infra
	$(MAKE) build-image
	$(MAKE) ecr-login
	$(MAKE) push-image
	$(MAKE) deploy-vpc
	$(MAKE) deploy-app
	$(MAKE) alb-dns

destroyall:
	$(MAKE) destroy-app
	$(MAKE) purge-alb-enis
	$(MAKE) vpc-destroy
	$(MAKE) registry-destroy
	$(MAKE) tf-backend-bucket-delete

redeploy-metrics:
	@echo ">> Reconstruyendo imagen Docker..."
	$(MAKE) build-image
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imagen a ECR..."
	$(MAKE) push-image
	@echo ">> Forzando actualización del servicio ECS..."
	@aws ecs update-service --cluster metricas-cluster --service metricas-svc --force-new-deployment --region $(REGION) --output json | jq -r '.service | "Deployment iniciado: \(.deployments[0].id)\nEstado: \(.deployments[0].rolloutState)\nTask Definition: \(.taskDefinition)"' || \
	  aws ecs update-service --cluster metricas-cluster --service metricas-svc --force-new-deployment --region $(REGION) --output text --query 'service.serviceName' | xargs -I {} echo "Deployment iniciado para servicio: {}"
	@echo ">> Redeploy iniciado. El servicio se actualizará en unos minutos."
	@echo ">> Verifica el estado con: make service-status"

stop-metrics:
	@echo ">> Deteniendo servicio de métricas (preservando imagen en ECR)..."
	$(MAKE) destroy-app
	$(MAKE) purge-alb-enis
	@echo ">> Servicio detenido. La imagen en ECR se mantiene intacta."
	@echo ">> Para restaurar, ejecuta: make restore-metrics"

restore-metrics:
	@echo ">> Restaurando servicio de métricas desde imagen existente en ECR..."
	@echo ">> Asumiendo que registry y VPC ya existen..."
	$(MAKE) deploy-app
	$(MAKE) alb-dns
	@echo ">> Servicio restaurado. Verifica el estado con: make service-status"
