# =========
# Variables
# =========
CURDIR            ?= $(shell pwd)
TERRAFORM_ENV     ?= student
REGION            ?= us-east-1
TF_BACKEND_BUCKET ?= infrastructura-maia-g8
ACCOUNT_ID        ?= $(shell aws sts get-caller-identity --query Account --output text 2>/dev/null)

# ================
# Bucket S3
# ================
.PHONY: tf-backend-bucket tf-backend-bucket-delete
tf-backend-bucket:
	@echo ">> Verificando bucket S3: $(TF_BACKEND_BUCKET) en $(REGION)"
	@if aws s3api head-bucket --bucket $(TF_BACKEND_BUCKET) 2>/dev/null; then \
	  echo "   Bucket ya existe."; \
	else \
	  echo "   Bucket no existe. Intentando crearlo..."; \
	  if [ "$(REGION)" = "us-east-1" ]; then \
	    aws s3api create-bucket --bucket $(TF_BACKEND_BUCKET) --region $(REGION) 2>&1 || true; \
	  else \
	    aws s3api create-bucket --bucket $(TF_BACKEND_BUCKET) --region $(REGION) \
	      --create-bucket-configuration LocationConstraint=$(REGION) 2>&1 || true; \
	  fi; \
	  sleep 2; \
	  if aws s3api head-bucket --bucket $(TF_BACKEND_BUCKET) 2>/dev/null; then \
	    echo "   Bucket creado exitosamente. Configurando..."; \
	  aws s3api put-bucket-versioning \
	      --bucket $(TF_BACKEND_BUCKET) --versioning-configuration Status=Enabled 2>&1 || echo "   WARNING: No se pudo habilitar versionado"; \
	  aws s3api put-bucket-encryption \
	    --bucket $(TF_BACKEND_BUCKET) \
	      --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}' 2>&1 || echo "   WARNING: No se pudo habilitar encriptación"; \
	  else \
	    echo "   WARNING: El bucket no existe y no se pudo crear."; \
	    echo "   Continuando de todas formas (el bucket debe existir previamente)."; \
	  fi; \
	fi

tf-backend-bucket-delete:
	@echo ">> Eliminando objetos versionados en s3://$(TF_BACKEND_BUCKET)"
	@if [ "$(TF_BACKEND_BUCKET)" = "infrastructura-maia-g8" ]; then \
	  echo "   WARNING: El bucket 'infrastructura-maia-g8' está protegido y NO será eliminado."; \
	  echo "   Solo se eliminarán los objetos dentro del bucket."; \
	  aws s3api list-object-versions --bucket $(TF_BACKEND_BUCKET) --output json | \
	    jq -r '.Versions[]?, .DeleteMarkers[]? | {Key:.Key, VersionId:.VersionId} | @json' | \
	    while read -r obj; do \
	      key=$$(echo $$obj | jq -r .Key); \
	      vid=$$(echo $$obj | jq -r .VersionId); \
	      aws s3api delete-object --bucket $(TF_BACKEND_BUCKET) --key "$$key" --version-id "$$vid" >/dev/null; \
	    done || true; \
	  echo ">> Objetos eliminados. El bucket se mantiene intacto."; \
	else \
	  aws s3api list-object-versions --bucket $(TF_BACKEND_BUCKET) --output json | \
	  jq -r '.Versions[]?, .DeleteMarkers[]? | {Key:.Key, VersionId:.VersionId} | @json' | \
	  while read -r obj; do \
	    key=$$(echo $$obj | jq -r .Key); \
	    vid=$$(echo $$obj | jq -r .VersionId); \
	    aws s3api delete-object --bucket $(TF_BACKEND_BUCKET) --key "$$key" --version-id "$$vid" >/dev/null; \
	    done || true; \
	  echo ">> Eliminando bucket s3://$(TF_BACKEND_BUCKET)"; \
	  aws s3api delete-bucket --bucket $(TF_BACKEND_BUCKET) --region $(REGION) || true; \
	fi

# =========================
# Terraform Stack (genérico)
# =========================
.PHONY: tfinit tfplan tfapply tfdestroy
tfinit:
	@rm -f terraform/stacks/${STACK}/.terraform.lock.hcl
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
	@echo ">> Limpiando locks y ejecutando init..."
	@rm -f terraform/stacks/registry/.terraform.lock.hcl
	$(MAKE) registry-init
	$(MAKE) tfdestroy STACK=registry TERRAFORM_ENV=$(TERRAFORM_ENV)

# =========================
# Docker Image
# =========================
.PHONY: build-metricas-image build-generador-image ecr-login push-metricas-image push-generador-image
build-metricas-image:
	docker build --rm --platform linux/amd64 --no-cache -f metricas/Dockerfile -t metricas-api:latest ./metricas

build-generador-image:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make build-generador-image MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  echo "       Primero ejecuta el notebook generator_app/merge_and_upload_to_s3.ipynb para hacer merge y subir a S3"; \
	  exit 1; \
	fi
	@echo ">> Verificando que el modelo mergeado existe en S3..."
	@aws s3 ls s3://modelo-generador-maia-g8/merged-models/$(MODEL_NAME)/config.json --region $(REGION) >/dev/null 2>&1 || { \
	  echo "ERROR: El modelo mergeado no se encuentra en S3: s3://modelo-generador-maia-g8/merged-models/$(MODEL_NAME)/"; \
	  echo "       Primero ejecuta el notebook generator_app/merge_and_upload_to_s3.ipynb para hacer merge y subir a S3"; \
	  exit 1; \
	}
	@echo ">> Construyendo imagen Docker localmente..."
	docker build --rm --platform linux/amd64 --no-cache \
	  --build-arg MODEL_NAME=$(MODEL_NAME) \
	  -f generator_app/Dockerfile \
	  -t generador-api:latest \
	  ./generator_app

ecr-login:
	aws ecr get-login-password --region $(REGION) | docker login --username AWS --password-stdin "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com"

push-metricas-image:
	docker tag "metricas-api:latest" "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/metricas-api:latest"
	docker push "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/metricas-api:latest"

push-generador-image:
	docker tag "generador-api:latest" "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/generador-api:latest"
	docker push "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/generador-api:latest"



# =========================
# Terraform Stacks
# =========================
.PHONY: vpc-init vpc-plan vpc-apply vpc-destroy \
        ecs-init ecs-plan ecs-apply ecs-destroy \
        alb-init alb-plan alb-apply alb-destroy \
        metricas-init metricas-plan metricas-apply metricas-destroy \
        generador-init generador-plan generador-apply generador-destroy

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
	@echo ">> Limpiando locks y ejecutando init..."
	@rm -f terraform/stacks/vpc/.terraform.lock.hcl
	$(MAKE) vpc-init
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
	@echo ">> Limpiando locks y ejecutando init..."
	@rm -f terraform/stacks/ecs/.terraform.lock.hcl
	$(MAKE) ecs-init
	$(MAKE) tfdestroy STACK=ecs TERRAFORM_ENV=$(TERRAFORM_ENV)

# ALB
alb-init:
	$(MAKE) tfinit STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)
alb-plan:
	@if [ ! -d "terraform/stacks/alb/.terraform" ]; then $(MAKE) alb-init; fi
	$(MAKE) tfplan STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)
alb-apply:
	@if [ ! -d "terraform/stacks/alb/.terraform" ]; then $(MAKE) alb-init; fi
	@echo ">> Verificando target groups existentes (NLB)..."; \
	TG_GEN_ARN=$$(aws elbv2 describe-target-groups --names metricas-nlb-generador-tg --region $(REGION) --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null | grep -v "^None$$" || true); \
	TG_MET_ARN=$$(aws elbv2 describe-target-groups --names metricas-nlb-metricas-tg --region $(REGION) --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null | grep -v "^None$$" || true); \
	if [ -n "$$TG_GEN_ARN" ] && [ "$$TG_GEN_ARN" != "None" ]; then \
	  echo ">> Target group 'metricas-nlb-generador-tg' encontrado: $$TG_GEN_ARN"; \
	  if ! terraform -chdir="terraform/stacks/alb" state show module.nlb_generador.aws_lb_target_group.this >/dev/null 2>&1; then \
	    echo ">> Importando target group generador a Terraform..."; \
	    cd terraform/stacks/alb && \
	    terraform import -var-file="../../environments/student/alb/terraform.tfvars" module.nlb_generador.aws_lb_target_group.this $$TG_GEN_ARN 2>&1 | grep -v "Warning:" || echo ">> Import completado (o ya estaba importado)"; \
	    cd ../../..; \
	  fi; \
	fi; \
	if [ -n "$$TG_MET_ARN" ] && [ "$$TG_MET_ARN" != "None" ]; then \
	  echo ">> Target group 'metricas-nlb-metricas-tg' encontrado: $$TG_MET_ARN"; \
	  if ! terraform -chdir="terraform/stacks/alb" state show module.nlb_metricas.aws_lb_target_group.this >/dev/null 2>&1; then \
	    echo ">> Importando target group métricas a Terraform..."; \
	    cd terraform/stacks/alb && \
	    terraform import -var-file="../../environments/student/alb/terraform.tfvars" module.nlb_metricas.aws_lb_target_group.this $$TG_MET_ARN 2>&1 | grep -v "Warning:" || echo ">> Import completado (o ya estaba importado)"; \
	    cd ../../..; \
	  fi; \
	fi
	@if [ ! -f "alb.tfplan" ]; then $(MAKE) alb-plan; fi
	$(MAKE) tfapply STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)
alb-destroy:
	@echo ">> Limpiando locks y ejecutando init..."
	@rm -f terraform/stacks/alb/.terraform.lock.hcl
	$(MAKE) alb-init
	$(MAKE) tfdestroy STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)

# Métricas
metricas-init:
	$(MAKE) tfinit STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)
metricas-plan:
	@if [ ! -d "terraform/stacks/app/.terraform" ]; then $(MAKE) metricas-init; fi
	$(MAKE) tfplan STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)
metricas-apply:
	@if [ ! -d "terraform/stacks/app/.terraform" ]; then $(MAKE) metricas-init; fi
	@if [ ! -f "app.tfplan" ]; then $(MAKE) metricas-plan; fi
	$(MAKE) tfapply STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)
metricas-destroy:
	@echo ">> Limpiando locks y ejecutando init..."
	@rm -f terraform/stacks/app/.terraform.lock.hcl
	$(MAKE) metricas-init
	$(MAKE) tfdestroy STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)

# Generador
generador-init:
	$(MAKE) tfinit STACK=generador TERRAFORM_ENV=$(TERRAFORM_ENV)
generador-plan:
	@if [ ! -d "terraform/stacks/generador/.terraform" ]; then $(MAKE) generador-init; fi
	$(MAKE) tfplan STACK=generador TERRAFORM_ENV=$(TERRAFORM_ENV)
generador-apply:
	@if [ ! -d "terraform/stacks/generador/.terraform" ]; then $(MAKE) generador-init; fi
	@if [ ! -f "generador.tfplan" ]; then $(MAKE) generador-plan; fi
	$(MAKE) tfapply STACK=generador TERRAFORM_ENV=$(TERRAFORM_ENV)
generador-destroy:
	@echo ">> Limpiando locks y ejecutando init..."
	@rm -f terraform/stacks/generador/.terraform.lock.hcl
	$(MAKE) generador-init
	$(MAKE) tfdestroy STACK=generador TERRAFORM_ENV=$(TERRAFORM_ENV)

# =========================
# Orquestación
# =========================
.PHONY: deploy-infra deploy-vpc deploy-metricas deploy-generador destroy-metricas destroy-generador
deploy-infra:
	$(MAKE) registry-init
	$(MAKE) registry-plan
	$(MAKE) registry-apply

deploy-vpc:
	$(MAKE) vpc-init
	$(MAKE) vpc-plan
	$(MAKE) vpc-apply

deploy-metricas:
	@echo ">> Desplegando métricas (infraestructura completa)..."
	$(MAKE) deploy-infra
	$(MAKE) deploy-vpc
	$(MAKE) ecs-init
	$(MAKE) ecs-plan
	$(MAKE) ecs-apply
	$(MAKE) alb-init
	$(MAKE) alb-plan
	$(MAKE) alb-apply
	@echo ">> Construyendo imagen Docker de métricas..."
	$(MAKE) build-metricas-image
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imagen de métricas a ECR..."
	$(MAKE) push-metricas-image
	$(MAKE) metricas-init
	$(MAKE) metricas-plan
	$(MAKE) metricas-apply

deploy-generador:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make deploy-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  echo "       Primero ejecuta el notebook generator_app/merge_and_upload_to_s3.ipynb para hacer merge y subir a S3"; \
	  exit 1; \
	fi
	@echo ">> Desplegando generador (infraestructura completa)..."
	@echo ">> MODEL_NAME: $(MODEL_NAME)"
	$(MAKE) deploy-infra
	$(MAKE) deploy-vpc
	$(MAKE) ecs-init
	$(MAKE) ecs-plan
	$(MAKE) ecs-apply
	$(MAKE) alb-init
	$(MAKE) alb-plan
	$(MAKE) alb-apply
	@echo ">> Construyendo imagen Docker del generador..."
	$(MAKE) build-generador-image MODEL_NAME=$(MODEL_NAME)
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imagen a ECR..."
	$(MAKE) push-generador-image
	@echo ">> Actualizando MODEL_NAME en terraform.tfvars..."
	@sed -i 's/MODEL_NAME = ".*"/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars || \
	  sed -i 's/MODEL_NAME = .*/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars
	$(MAKE) generador-init
	$(MAKE) generador-plan
	$(MAKE) generador-apply
	$(MAKE) alb-dns
	@echo ">> Despliegue del generador completado."

destroy-metricas:
	$(MAKE) metricas-destroy

destroy-generador:
	$(MAKE) generador-destroy

# =========================
# Utilidades
# =========================
.PHONY: alb-dns purge-alb-enis metricas-status generador-status
alb-dns:
	@echo ">> Obteniendo DNS de los NLB..."
	@if terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_generador_dns_name >/dev/null 2>&1; then \
	  DNS_GEN=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_generador_dns_name 2>&1 | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r '); \
	  DNS_MET=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_metricas_dns_name 2>&1 | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r '); \
	  if [ -n "$$DNS_GEN" ] && [ "$$DNS_GEN" != "null" ]; then \
	    echo ""; \
	    echo "========================================="; \
	    echo "  URLs de los servicios:"; \
	    echo "========================================="; \
	    echo "  Generador:  http://$$DNS_GEN:8000"; \
	    echo "  Métricas:   http://$$DNS_MET:8001"; \
	    echo ""; \
	    echo "  Endpoints:"; \
	    echo "  - Generador health: http://$$DNS_GEN:8000/healthz"; \
	    echo "  - Generador generate: http://$$DNS_GEN:8000/generate"; \
	    echo "  - Métricas health: http://$$DNS_MET:8001/healthz"; \
	    echo "  - Métricas readability: http://$$DNS_MET:8001/metrics/readability"; \
	    echo "  - Métricas relevance: http://$$DNS_MET:8001/metrics/relevance"; \
	    echo "  - Métricas factuality: http://$$DNS_MET:8001/metrics/factuality"; \
	    echo "  - Métricas loss: http://$$DNS_MET:8001/loss"; \
	    echo "========================================="; \
	    echo ""; \
	  else \
	    echo "   NLB aún no desplegado. Ejecuta: make alb-apply"; \
	  fi; \
	else \
	  echo "   NLB aún no desplegado. Ejecuta: make alb-apply"; \
	fi

metricas-status:
	@echo ">> Estado del servicio de métricas..."
	@aws ecs describe-services \
	  --cluster cluster_g3_MAIA \
	  --services metricas-svc \
	  --region $(REGION) \
	  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Events:events[0:3]}' \
	  --output json | jq '.' || echo "Error al obtener el estado del servicio"

generador-status:
	@echo ">> Estado del servicio generador..."
	@aws ecs describe-services \
	  --cluster cluster_g3_MAIA \
	  --services generador-svc \
	  --region $(REGION) \
	  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Events:events[0:3]}' \
	  --output json | jq '.' || echo "Error al obtener el estado del servicio"

purge-alb-enis:
	@echo ">> NLB no usa security groups, no hay ENIs que limpiar."

# =========================
# Shortcuts Principales
# =========================
.PHONY: startall destroyall redeploy-metricas redeploy-generador stop-metricas stop-generador restore-metricas restore-generador stopall restoreall
startall:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make startall MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  echo "       Primero ejecuta el notebook generator_app/merge_and_upload_to_s3.ipynb para hacer merge y subir a S3"; \
	  exit 1; \
	fi
	@echo ">> Desplegando infraestructura completa (métricas + generador)..."
	$(MAKE) deploy-infra
	$(MAKE) deploy-vpc
	$(MAKE) ecs-init
	$(MAKE) ecs-plan
	$(MAKE) ecs-apply
	$(MAKE) alb-init
	$(MAKE) alb-plan
	$(MAKE) alb-apply
	@echo ">> Construyendo imágenes Docker..."
	$(MAKE) build-metricas-image
	$(MAKE) build-generador-image MODEL_NAME=$(MODEL_NAME)
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imágenes a ECR..."
	$(MAKE) push-metricas-image
	$(MAKE) push-generador-image
	@echo ">> Desplegando métricas..."
	$(MAKE) metricas-init
	$(MAKE) metricas-plan
	$(MAKE) metricas-apply
	@echo ">> Desplegando generador..."
	@sed -i 's/MODEL_NAME = ".*"/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars || \
	  sed -i 's/MODEL_NAME = .*/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars
	$(MAKE) generador-init
	$(MAKE) generador-plan
	$(MAKE) generador-apply
	$(MAKE) alb-dns

destroyall:
	@echo ">> Destruyendo todos los servicios..."
	$(MAKE) destroy-generador
	$(MAKE) destroy-metricas
	$(MAKE) alb-destroy
	$(MAKE) ecs-destroy
	$(MAKE) purge-alb-enis
	$(MAKE) vpc-destroy
	$(MAKE) registry-destroy
	$(MAKE) tf-backend-bucket-delete

redeploy-metricas:
	@echo ">> Reconstruyendo imagen Docker de métricas..."
	$(MAKE) build-metricas-image
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imagen a ECR..."
	$(MAKE) push-metricas-image
	@echo ">> Forzando actualización del servicio ECS..."
	@aws ecs update-service --cluster cluster_g3_MAIA --service metricas-svc --force-new-deployment --region $(REGION) --output json | jq -r '.service | "Deployment iniciado: \(.deployments[0].id)\nEstado: \(.deployments[0].rolloutState)\nTask Definition: \(.taskDefinition)"' || \
	  aws ecs update-service --cluster cluster_g3_MAIA --service metricas-svc --force-new-deployment --region $(REGION) --output text --query 'service.serviceName' | xargs -I {} echo "Deployment iniciado para servicio: {}"
	@echo ">> Redeploy iniciado. El servicio se actualizará en unos minutos."
	@echo ">> Verifica el estado con: make metricas-status"

redeploy-generador:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make redeploy-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  exit 1; \
	fi
	@echo ">> Reconstruyendo imagen Docker del generador..."
	$(MAKE) build-generador-image MODEL_NAME=$(MODEL_NAME)
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imagen a ECR..."
	$(MAKE) push-generador-image
	@echo ">> Forzando actualización del servicio ECS..."
	@aws ecs update-service --cluster cluster_g3_MAIA --service generador-svc --force-new-deployment --region $(REGION) --output json | jq -r '.service | "Deployment iniciado: \(.deployments[0].id)\nEstado: \(.deployments[0].rolloutState)\nTask Definition: \(.taskDefinition)"' || \
	  aws ecs update-service --cluster cluster_g3_MAIA --service generador-svc --force-new-deployment --region $(REGION) --output text --query 'service.serviceName' | xargs -I {} echo "Deployment iniciado para servicio: {}"
	@echo ">> Redeploy iniciado. El servicio se actualizará en unos minutos."
	@echo ">> Verifica el estado con: make generador-status"

stop-metricas:
	@echo ">> Deteniendo servicio de métricas (preservando imagen en ECR)..."
	$(MAKE) destroy-metricas
	@echo ">> Servicio detenido. La imagen en ECR se mantiene intacta."
	@echo ">> Para restaurar, ejecuta: make restore-metricas"

stop-generador:
	@echo ">> Deteniendo servicio generador (preservando imagen en ECR)..."
	$(MAKE) destroy-generador
	@echo ">> Servicio detenido. La imagen en ECR se mantiene intacta."
	@echo ">> Para restaurar, ejecuta: make restore-generador MODEL_NAME=..."

restore-metricas:
	@echo ">> Restaurando servicio de métricas desde imagen existente en ECR..."
	@echo ">> Asumiendo que registry, VPC, ECS y ALB ya existen..."
	@echo ">> NO se reconstruirá ni se empujará la imagen (usando imagen existente en ECR)..."
	$(MAKE) metricas-init
	$(MAKE) metricas-plan
	$(MAKE) metricas-apply
	$(MAKE) alb-dns
	@echo ">> Servicio restaurado. Verifica el estado con: make metricas-status"

restore-generador:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make restore-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  exit 1; \
	fi
	@echo ">> Restaurando servicio generador desde imagen existente en ECR..."
	@echo ">> Asumiendo que registry, VPC, ECS y ALB ya existen..."
	@echo ">> NO se reconstruirá ni se empujará la imagen (usando imagen existente en ECR)..."
	@sed -i 's/MODEL_NAME = ".*"/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars || \
	  sed -i 's/MODEL_NAME = .*/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars
	$(MAKE) generador-init
	$(MAKE) generador-plan
	$(MAKE) generador-apply
	$(MAKE) alb-dns
	@echo ">> Servicio restaurado. Verifica el estado con: make generador-status"

stopall:
	@echo ">> Deteniendo todos los servicios, load balancers y cluster ECS (preservando imágenes en ECR)..."
	@echo ">> Deteniendo servicio de métricas..."
	$(MAKE) destroy-metricas
	@echo ">> Deteniendo servicio generador..."
	$(MAKE) destroy-generador
	@echo ">> Destruyendo load balancers (NLB)..."
	$(MAKE) alb-destroy
	@echo ">> Destruyendo cluster ECS..."
	$(MAKE) ecs-destroy
	@echo ">> Todos los servicios, load balancers y cluster ECS detenidos."
	@echo ">> ECS está ahora vacío."
	@echo ">> Las imágenes en ECR se mantienen intactas."
	@echo ">> Para restaurar todo, ejecuta: make restoreall MODEL_NAME=..."

restoreall:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make restoreall MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  exit 1; \
	fi
	@echo ">> Restaurando toda la infraestructura (cluster ECS + servicios + load balancers)..."
	@echo ">> Asumiendo que registry y VPC ya existen..."
	@echo ">> NO se reconstruirán ni se empujarán las imágenes (usando imágenes existentes en ECR)..."
	@echo ">> Recreando cluster ECS..."
	$(MAKE) ecs-init
	$(MAKE) ecs-plan
	$(MAKE) ecs-apply
	@echo ">> Recreando load balancers (NLB)..."
	$(MAKE) alb-init
	$(MAKE) alb-plan
	$(MAKE) alb-apply
	@echo ">> Restaurando servicio de métricas..."
	$(MAKE) metricas-init
	$(MAKE) metricas-plan
	$(MAKE) metricas-apply
	@echo ">> Restaurando servicio generador..."
	@sed -i 's/MODEL_NAME = ".*"/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars || \
	  sed -i 's/MODEL_NAME = .*/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars
	$(MAKE) generador-init
	$(MAKE) generador-plan
	$(MAKE) generador-apply
	@echo ">> Mostrando URLs de los servicios..."
	$(MAKE) alb-dns
	@echo ">> Todos los servicios, load balancers y cluster ECS restaurados."
	@echo ">> Verifica el estado con: make metricas-status y make generador-status"
