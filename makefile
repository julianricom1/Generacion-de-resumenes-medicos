# =========
# Variables
# =========
CURDIR            ?= $(shell pwd)
TERRAFORM_ENV     ?= student
REGION            ?= us-east-1
TF_BACKEND_BUCKET ?= infrastructura-maia-g3
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
	@if [ "$(TF_BACKEND_BUCKET)" = "infrastructura-maia-g3" ]; then \
	  echo "   WARNING: El bucket 'infrastructura-maia-g3' está protegido y NO será eliminado."; \
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
.PHONY: build-metricas-image build-generador-image build-clasificador-api-image build-web-image ecr-login push-metricas-image push-generador-image push-clasificador-api-image push-web-image
build-metricas-image:
	DOCKER_BUILDKIT=0 docker build --rm --platform linux/amd64 --no-cache -f metricas/Dockerfile -t metricas-api:latest ./metricas

build-generador-image:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make build-generador-image MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  echo "       Primero ejecuta el notebook generator_app/merge_and_upload_to_s3.ipynb para hacer merge y subir a S3"; \
	  exit 1; \
	fi
	@echo ">> Verificando que el modelo mergeado existe en S3..."
	@aws s3 ls s3://modelo-generador-maia-g3/merged-models/$(MODEL_NAME)/config.json --region $(REGION) >/dev/null 2>&1 || { \
	  echo "ERROR: El modelo mergeado no se encuentra en S3: s3://modelo-generador-maia-g3/merged-models/$(MODEL_NAME)/"; \
	  echo "       Primero ejecuta el notebook generator_app/merge_and_upload_to_s3.ipynb para hacer merge y subir a S3"; \
	  exit 1; \
	}
	@echo ">> Construyendo imagen Docker localmente..."
	DOCKER_BUILDKIT=0 docker build --rm --platform linux/amd64 --no-cache \
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

push-clasificador-api-image:
	@echo ">> Verificando que el repositorio ECR 'clasificador-api' existe..."
	@aws ecr describe-repositories --repository-names clasificador-api --region $(REGION) >/dev/null 2>&1 || { \
	  echo "ERROR: El repositorio ECR 'clasificador-api' no existe."; \
	  echo "       Ejecuta primero: make deploy-infra"; \
	  exit 1; \
	}
	@echo ">> Etiquetando imagen para ECR..."
	docker tag "clasificador-api:latest" "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/clasificador-api:latest"
	@echo ">> Subiendo imagen a ECR..."
	docker push "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/clasificador-api:latest"
	@echo ">> Imagen del clasificador-api subida exitosamente a ECR"

build-clasificador-api-image:
	@echo ">> Construyendo imagen Docker del clasificador-api..."
	@echo ">> Esto puede tardar varios minutos (multi-stage build con dependencias Python)..."
	@echo ">> Stage 1: Builder (instalando build-essential y dependencias)..."
	@echo ">> Stage 2: Runtime (configurando entorno final)..."
	docker build --rm --platform linux/amd64 --no-cache \
	  -f clasificador_app/Dockerfile \
	  -t clasificador-api:latest \
	  .
	@echo ">> Build del clasificador-api completado exitosamente"

build-web-image:
	@echo ">> Extrayendo endpoints de los servicios backend..."
	@DNS_GEN=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_generador_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	DNS_MET=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_metricas_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	DNS_CLAS=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_clasificador_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	if [ -z "$$DNS_GEN" ] || [ "$$DNS_GEN" = "null" ] || [ -z "$$DNS_MET" ] || [ "$$DNS_MET" = "null" ] || [ -z "$$DNS_CLAS" ] || [ "$$DNS_CLAS" = "null" ]; then \
	  echo "ERROR: Los servicios backend no están desplegados. Ejecuta primero:"; \
	  echo "  make deploy-metricas"; \
	  echo "  make deploy-generador MODEL_NAME=..."; \
	  echo "  make deploy-clasificador"; \
	  echo "  make show_endpoints"; \
	  exit 1; \
	fi; \
	VITE_GENERATION_DOMAIN="http://$$DNS_GEN:8000"; \
	VITE_METRICS_DOMAIN="http://$$DNS_MET:8001"; \
	VITE_CLASSIFICATION_DOMAIN="http://$$DNS_CLAS:8002"; \
	echo ">> Endpoints extraídos:"; \
	echo "  VITE_GENERATION_DOMAIN=$$VITE_GENERATION_DOMAIN"; \
	echo "  VITE_METRICS_DOMAIN=$$VITE_METRICS_DOMAIN"; \
	echo "  VITE_CLASSIFICATION_DOMAIN=$$VITE_CLASSIFICATION_DOMAIN"; \
	echo ">> Construyendo imagen Docker del web (React + Vite)..."; \
	echo ">> Esto puede tardar varios minutos (instalación de dependencias Node.js y build)..."; \
	docker build --rm --platform linux/amd64 --no-cache \
	  --build-arg VITE_GENERATION_DOMAIN="$$VITE_GENERATION_DOMAIN" \
	  --build-arg VITE_METRICS_DOMAIN="$$VITE_METRICS_DOMAIN" \
	  --build-arg VITE_CLASSIFICATION_DOMAIN="$$VITE_CLASSIFICATION_DOMAIN" \
	  -f web/Dockerfile \
	  -t web:latest \
	  .
	@echo ">> Build del web completado exitosamente"

push-web-image:
	@echo ">> Verificando que el repositorio ECR 'web' existe..."
	@aws ecr describe-repositories --repository-names web --region $(REGION) >/dev/null 2>&1 || { \
	  echo "ERROR: El repositorio ECR 'web' no existe. Ejecuta 'make deploy-infra' primero."; \
	  exit 1; \
	}
	@echo ">> Etiquetando imagen para ECR..."
	docker tag "web:latest" "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/web:latest"
	@echo ">> Subiendo imagen a ECR..."
	docker push "$(ACCOUNT_ID).dkr.ecr.$(REGION).amazonaws.com/web:latest"
	@echo ">> Imagen del web subida exitosamente a ECR"

# =========================
# Terraform Stacks
# =========================
.PHONY: vpc-init vpc-plan vpc-apply vpc-destroy \
        ecs-init ecs-plan ecs-apply ecs-destroy \
        lb-init lb-plan lb-apply lb-destroy \
        metricas-init metricas-plan metricas-apply metricas-destroy \
        generador-init generador-plan generador-apply generador-destroy \
        clasificador-api-init clasificador-api-plan clasificador-api-apply clasificador-api-destroy \
        web-init web-plan web-apply web-destroy

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

# LB
lb-init:
	$(MAKE) tfinit STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)
lb-plan:
	@if [ ! -d "terraform/stacks/alb/.terraform" ]; then $(MAKE) lb-init; fi
	$(MAKE) tfplan STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)
lb-apply:
	@if [ ! -d "terraform/stacks/alb/.terraform" ]; then $(MAKE) lb-init; fi
	@echo ">> Verificando target groups existentes (NLB compartido)..."; \
	TG_GEN_ARN=$$(aws elbv2 describe-target-groups --names metricas-nlb-generador-tg --region $(REGION) --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null | grep -v "^None$$" || true); \
	TG_MET_ARN=$$(aws elbv2 describe-target-groups --names metricas-nlb-metricas-tg --region $(REGION) --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null | grep -v "^None$$" || true); \
	TG_CLAS_ARN=$$(aws elbv2 describe-target-groups --names metricas-nlb-clasificador-tg --region $(REGION) --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null | grep -v "^None$$" || true); \
	if [ -n "$$TG_GEN_ARN" ] && [ "$$TG_GEN_ARN" != "None" ]; then \
	  echo ">> Target group 'metricas-nlb-generador-tg' encontrado: $$TG_GEN_ARN"; \
	  if ! terraform -chdir="terraform/stacks/alb" state show aws_lb_target_group.generador >/dev/null 2>&1; then \
	    echo ">> Importando target group generador a Terraform..."; \
	    cd terraform/stacks/alb && \
	    terraform import -var-file="../../environments/student/alb/terraform.tfvars" aws_lb_target_group.generador $$TG_GEN_ARN 2>&1 | grep -v "Warning:" || echo ">> Import completado (o ya estaba importado)"; \
	    cd ../../..; \
	  fi; \
	fi; \
	if [ -n "$$TG_MET_ARN" ] && [ "$$TG_MET_ARN" != "None" ]; then \
	  echo ">> Target group 'metricas-nlb-metricas-tg' encontrado: $$TG_MET_ARN"; \
	  if ! terraform -chdir="terraform/stacks/alb" state show aws_lb_target_group.metricas >/dev/null 2>&1; then \
	    echo ">> Importando target group métricas a Terraform..."; \
	    cd terraform/stacks/alb && \
	    terraform import -var-file="../../environments/student/alb/terraform.tfvars" aws_lb_target_group.metricas $$TG_MET_ARN 2>&1 | grep -v "Warning:" || echo ">> Import completado (o ya estaba importado)"; \
	    cd ../../..; \
	  fi; \
	fi; \
	if [ -n "$$TG_CLAS_ARN" ] && [ "$$TG_CLAS_ARN" != "None" ]; then \
	  echo ">> Target group 'metricas-nlb-clasificador-tg' encontrado: $$TG_CLAS_ARN"; \
	  if ! terraform -chdir="terraform/stacks/alb" state show aws_lb_target_group.clasificador >/dev/null 2>&1; then \
	    echo ">> Importando target group clasificador a Terraform..."; \
	    cd terraform/stacks/alb && \
	    terraform import -var-file="../../environments/student/alb/terraform.tfvars" aws_lb_target_group.clasificador $$TG_CLAS_ARN 2>&1 | grep -v "Warning:" || echo ">> Import completado (o ya estaba importado)"; \
	    cd ../../..; \
	  fi; \
	fi
	@if [ ! -f "alb.tfplan" ]; then $(MAKE) lb-plan; fi
	$(MAKE) tfapply STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)
lb-destroy:
	@echo ">> Limpiando locks y ejecutando init..."
	@rm -f terraform/stacks/alb/.terraform.lock.hcl
	$(MAKE) lb-init
	$(MAKE) tfdestroy STACK=alb TERRAFORM_ENV=$(TERRAFORM_ENV)

# Métricas
metricas-init:
	@echo ">> Inicializando backend de métricas..."
	@rm -f terraform/stacks/app/.terraform.lock.hcl
	$(MAKE) tfinit STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)
metricas-plan:
	@echo ">> Asegurando backend correcto de métricas..."
	@$(MAKE) metricas-init
	$(MAKE) tfplan STACK=app TERRAFORM_ENV=$(TERRAFORM_ENV)
metricas-apply:
	@echo ">> Asegurando backend correcto de métricas..."
	@$(MAKE) metricas-init
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
	@echo ">> Leyendo API keys desde KEYS.py y agregándolas a terraform.tfvars..."
	@python3 scripts/add_api_keys_to_tfvars.py || python scripts/add_api_keys_to_tfvars.py
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

# Clasificador API
clasificador-api-init:
	@echo ">> Inicializando backend de clasificador-api..."
	@rm -f terraform/stacks/app/.terraform.lock.hcl
	terraform -chdir="$(shell pwd)/terraform/stacks/app" init -reconfigure \
	  -backend-config="$(shell pwd)/terraform/environments/$(TERRAFORM_ENV)/clasificador-api/backend.tfvars"
clasificador-api-plan:
	@echo ">> Asegurando backend correcto de clasificador-api..."
	@$(MAKE) clasificador-api-init
	@echo ">> Obteniendo target group ARN del NLB..."
	@TG_ARN=$$(terraform -chdir="terraform/stacks/alb" output -raw nlb_clasificador_target_group_arn 2>/dev/null || echo ""); \
	if [ -n "$$TG_ARN" ] && [ "$$TG_ARN" != "" ]; then \
	  echo ">> Actualizando terraform.tfvars con target_group_arn..."; \
	  sed -i.bak "s|target_group_arn = .*|target_group_arn = \"$$TG_ARN\"|" terraform/environments/student/clasificador-api/terraform.tfvars; \
	  rm -f terraform/environments/student/clasificador-api/terraform.tfvars.bak; \
	fi
	terraform -chdir="$(shell pwd)/terraform/stacks/app" plan \
	  -var-file="$(shell pwd)/terraform/environments/$(TERRAFORM_ENV)/clasificador-api/terraform.tfvars" \
	  -out="clasificador-api.tfplan"
clasificador-api-apply:
	@echo ">> Asegurando backend correcto de clasificador-api..."
	@$(MAKE) clasificador-api-init
	@if [ ! -f "clasificador-api.tfplan" ]; then $(MAKE) clasificador-api-plan; fi
	terraform -chdir="$(shell pwd)/terraform/stacks/app" apply "clasificador-api.tfplan"
clasificador-api-destroy:
	@echo ">> Limpiando locks y ejecutando init..."
	@rm -f terraform/stacks/app/.terraform.lock.hcl
	$(MAKE) clasificador-api-init
	terraform -chdir="$(shell pwd)/terraform/stacks/app" destroy -auto-approve \
	  -var-file="$(shell pwd)/terraform/environments/$(TERRAFORM_ENV)/clasificador-api/terraform.tfvars"

# Web (Frontend)
web-init:
	$(MAKE) tfinit STACK=web TERRAFORM_ENV=$(TERRAFORM_ENV)
web-plan:
	@if [ ! -d "terraform/stacks/web/.terraform" ]; then $(MAKE) web-init; fi
	$(MAKE) tfplan STACK=web TERRAFORM_ENV=$(TERRAFORM_ENV)
web-apply:
	@if [ ! -d "terraform/stacks/web/.terraform" ]; then $(MAKE) web-init; fi
	@if [ ! -f "web.tfplan" ]; then $(MAKE) web-plan; fi
	$(MAKE) tfapply STACK=web TERRAFORM_ENV=$(TERRAFORM_ENV)
web-destroy:
	@echo ">> Limpiando locks y ejecutando init..."
	@rm -f terraform/stacks/web/.terraform.lock.hcl
	$(MAKE) web-init
	$(MAKE) tfdestroy STACK=web TERRAFORM_ENV=$(TERRAFORM_ENV)

destroy-web:
	@echo ">> Destruyendo servicio web..."
	$(MAKE) web-destroy
	@echo ">> Servicio web destruido"

deploy-web:
	@echo ">> Desplegando web (infraestructura completa)..."
	@echo ">> Verificando que los servicios backend estén desplegados..."
	@DNS_GEN=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_generador_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	DNS_MET=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_metricas_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	DNS_CLAS=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_clasificador_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	if [ -z "$$DNS_GEN" ] || [ "$$DNS_GEN" = "null" ] || [ -z "$$DNS_MET" ] || [ "$$DNS_MET" = "null" ] || [ -z "$$DNS_CLAS" ] || [ "$$DNS_CLAS" = "null" ]; then \
	  echo "ERROR: Los servicios backend no están desplegados. Ejecuta primero:"; \
	  echo "  make deploy-metricas"; \
	  echo "  make deploy-generador MODEL_NAME=..."; \
	  echo "  make deploy-clasificador"; \
	  exit 1; \
	fi; \
	echo ">> Servicios backend verificados. Continuando con el despliegue del web..."; \
	$(MAKE) deploy-infra; \
	$(MAKE) deploy-vpc; \
	$(MAKE) ecs-init; \
	$(MAKE) ecs-plan; \
	$(MAKE) ecs-apply; \
	$(MAKE) lb-init; \
	$(MAKE) lb-plan; \
	$(MAKE) lb-apply; \
	echo ">> Construyendo imagen Docker del web con endpoints dinámicos..."; \
	$(MAKE) build-web-image; \
	echo ">> Haciendo login a ECR..."; \
	$(MAKE) ecr-login; \
	echo ">> Subiendo imagen a ECR..."; \
	$(MAKE) push-web-image; \
	echo ">> Desplegando web..."; \
	$(MAKE) web-init; \
	$(MAKE) web-plan; \
	$(MAKE) web-apply; \
	echo ">> Despliegue del web completado."; \
	echo ">> Esperando a que el servicio esté estable..."; \
	@sleep 10; \
	$(MAKE) show_endpoints; \
	@echo ">> Verifica el estado con: make web-status"

destroy-web:
	@echo ">> Destruyendo servicio web..."
	$(MAKE) web-destroy
	@echo ">> Servicio web destruido"

web-status:
	@echo ">> Estado del servicio web..."
	@aws ecs describe-services \
	  --cluster cluster_g3_MAIA \
	  --services web-svc \
	  --region $(REGION) \
	  --query 'services[0].{ServiceName:serviceName,Status:status,DesiredCount:desiredCount,RunningCount:runningCount,PendingCount:pendingCount,TaskDefinition:taskDefinition}' \
	  --output table || echo "Servicio no encontrado o error al consultar"

# =========================
# Orquestación
# =========================
.PHONY: deploy-infra deploy-vpc deploy-metricas deploy-generador deploy-clasificador destroy-metricas destroy-generador destroy-clasificador
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
	$(MAKE) lb-init
	$(MAKE) lb-plan
	$(MAKE) lb-apply
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
	$(MAKE) lb-init
	$(MAKE) lb-plan
	$(MAKE) lb-apply
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
	$(MAKE) show_endpoints
	@echo ">> Despliegue del generador completado."

destroy-metricas:
	$(MAKE) metricas-destroy

destroy-generador:
	$(MAKE) generador-destroy

deploy-clasificador:
	@echo ">> Desplegando clasificador (infraestructura completa)..."
	$(MAKE) deploy-infra
	$(MAKE) deploy-vpc
	$(MAKE) ecs-init
	$(MAKE) ecs-plan
	$(MAKE) ecs-apply
	$(MAKE) lb-init
	$(MAKE) lb-plan
	$(MAKE) lb-apply
	@echo ">> Construyendo imagen Docker del clasificador-api..."
	$(MAKE) build-clasificador-api-image
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imagen a ECR..."
	$(MAKE) push-clasificador-api-image
	@echo ">> Desplegando clasificador-api..."
	$(MAKE) clasificador-api-init
	$(MAKE) clasificador-api-plan
	$(MAKE) clasificador-api-apply
	@echo ">> Despliegue del clasificador completado."
	@echo ">> Esperando a que el servicio esté estable..."
	@sleep 10
	$(MAKE) show_endpoints
	@echo ">> Verifica el estado con: make clasificador-status"

destroy-clasificador:
	$(MAKE) clasificador-api-destroy

# =========================
# Utilidades
# =========================
.PHONY: show_endpoints purge-lb-enis metricas-status generador-status clasificador-status web-status
show_endpoints:
	@echo ">> Obteniendo las direcciones de los servicios..."
	@DNS_GEN=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_generador_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	DNS_MET=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_metricas_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	DNS_CLAS=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_clasificador_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	if [ -z "$$DNS_GEN" ] || [ "$$DNS_GEN" = "null" ] || [ -z "$$DNS_MET" ] || [ "$$DNS_MET" = "null" ]; then \
	  echo "   NLB aún no desplegado. Ejecuta: make lb-apply"; \
	else \
	  echo ""; \
	  echo "================================================================"; \
	  echo "  Endpoints de los Servicios Disponibles"; \
	  echo "================================================================"; \
	  echo ""; \
	  echo "  Nota: Todos los servicios usan el mismo NLB con diferentes puertos"; \
	  echo ""; \
	  echo "    GENERADOR (Puerto 8000):"; \
	  echo "    Base URL: http://$$DNS_GEN:8000"; \
	  echo "    - Health (ECS):     http://$$DNS_GEN:8000/healthz"; \
	  echo "    - Health (API):     http://$$DNS_GEN:8000/api/v1/health"; \
	  echo "    - Generate:         http://$$DNS_GEN:8000/api/v1/generate"; \
	  echo "    - Docs:             http://$$DNS_GEN:8000/docs"; \
	  echo ""; \
	  echo "    MÉTRICAS (Puerto 8001):"; \
	  echo "    Base URL: http://$$DNS_MET:8001"; \
	  echo "    - Health:           http://$$DNS_MET:8001/healthz"; \
	  echo "    - Readability:      http://$$DNS_MET:8001/metrics/readability"; \
	  echo "    - Relevance:       http://$$DNS_MET:8001/metrics/relevance"; \
	  echo "    - Factuality:       http://$$DNS_MET:8001/metrics/factuality"; \
	  echo "    - Loss:             http://$$DNS_MET:8001/loss"; \
	  if [ -n "$$DNS_CLAS" ] && [ "$$DNS_CLAS" != "null" ]; then \
	    echo ""; \
	    echo "    CLASIFICADOR (Puerto 8002):"; \
	    echo "    Base URL: http://$$DNS_CLAS:8002"; \
	    echo "    - Health:           http://$$DNS_CLAS:8002/api/v1/health"; \
	    echo "    - Predict:          http://$$DNS_CLAS:8002/api/v1/predict"; \
	    echo "    - Docs:             http://$$DNS_CLAS:8002/docs"; \
	  fi; \
	  DNS_WEB=$$(terraform -chdir="$(CURDIR)/terraform/stacks/alb" output -raw nlb_web_dns_name 2>/dev/null | grep -v "^Warning:" | grep -v "^│" | tr -d '\n\r ' || echo ""); \
	  if [ -n "$$DNS_WEB" ] && [ "$$DNS_WEB" != "null" ]; then \
	    echo ""; \
	    echo "    WEB (Puerto 80):"; \
	    echo "    Base URL: http://$$DNS_WEB:80"; \
	    echo "    - Aplicación web:   http://$$DNS_WEB:80"; \
	  fi; \
	  echo ""; \
	  echo "================================================================"; \
	  echo ""; \
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

clasificador-status:
	@echo ">> Estado del servicio clasificador-api..."
	@aws ecs describe-services \
	  --cluster cluster_g3_MAIA \
	  --services clasificador-api-svc \
	  --region $(REGION) \
	  --query 'services[0].{Status:status,Running:runningCount,Desired:desiredCount,Events:events[0:3]}' \
	  --output json | jq '.' || echo "Error al obtener el estado del servicio"

purge-lb-enis:
	@echo ">> NLB no usa security groups, no hay ENIs que limpiar."

# =========================
# Shortcuts Principales
# =========================
.PHONY: startall destroyall redeploy-metricas redeploy-generador redeploy-max-specs redeploy-normal-specs redeploy-clasificador redeploy-web stop-metricas stop-generador stop-clasificador stop-web restore-metricas restore-generador restore-clasificador restore-web stopall restoreall
startall:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make startall MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  echo "       Primero ejecuta el notebook generator_app/merge_and_upload_to_s3.ipynb para hacer merge y subir a S3"; \
	  exit 1; \
	fi
	@echo ">> Desplegando infraestructura completa (métricas + generador + clasificador)..."
	$(MAKE) deploy-infra
	$(MAKE) deploy-vpc
	$(MAKE) ecs-init
	$(MAKE) ecs-plan
	$(MAKE) ecs-apply
	$(MAKE) lb-init
	$(MAKE) lb-plan
	$(MAKE) lb-apply
	@echo ">> Construyendo imágenes Docker..."
	$(MAKE) build-metricas-image
	$(MAKE) build-generador-image MODEL_NAME=$(MODEL_NAME)
	$(MAKE) build-clasificador-api-image
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imágenes a ECR..."
	$(MAKE) push-metricas-image
	$(MAKE) push-generador-image
	$(MAKE) push-clasificador-api-image
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
	@echo ">> Desplegando clasificador..."
	$(MAKE) clasificador-api-init
	$(MAKE) clasificador-api-plan
	$(MAKE) clasificador-api-apply
	@echo ">> Desplegando web (requiere que los backends estén online)..."
	$(MAKE) build-web-image
	$(MAKE) push-web-image
	$(MAKE) web-init
	$(MAKE) web-plan
	$(MAKE) web-apply
	$(MAKE) show_endpoints

destroyall:
	@echo ">> Destruyendo todos los servicios..."
	$(MAKE) destroy-generador
	$(MAKE) destroy-metricas
	$(MAKE) destroy-clasificador
	$(MAKE) destroy-web
	$(MAKE) lb-destroy
	$(MAKE) ecs-destroy
	$(MAKE) purge-lb-enis
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

redeploy-max-specs:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make redeploy-max-specs MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  exit 1; \
	fi
	@echo ">> Configurando generador con especificaciones máximas (16 CPU, 64 GB RAM)..."
	@echo ">> NOTA: Para 16 vCPU, Fargate requiere memoria en incrementos de 8 GB (32-120 GB)"
	@sed -i 's/^cpu            = [0-9][0-9]*/cpu            = 16384/' terraform/environments/student/generador/terraform.tfvars
	@sed -i 's/^memory         = [0-9][0-9]*/memory         = 65536/' terraform/environments/student/generador/terraform.tfvars
	@echo ">> Aplicando cambios en Terraform..."
	$(MAKE) generador-init
	$(MAKE) generador-plan
	$(MAKE) generador-apply
	@echo ">> Forzando actualización del servicio ECS..."
	@aws ecs update-service --cluster cluster_g3_MAIA --service generador-svc --force-new-deployment --region $(REGION) --output json | jq -r '.service | "Deployment iniciado: \(.deployments[0].id)\nEstado: \(.deployments[0].rolloutState)\nTask Definition: \(.taskDefinition)"' || \
	  aws ecs update-service --cluster cluster_g3_MAIA --service generador-svc --force-new-deployment --region $(REGION) --output text --query 'service.serviceName' | xargs -I {} echo "Deployment iniciado para servicio: {}"
	@echo ">> Redeploy con especificaciones máximas iniciado. El servicio se actualizará en unos minutos."
	@echo ">> Verifica el estado con: make generador-status"

redeploy-normal-specs:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make redeploy-normal-specs MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  exit 1; \
	fi
	@echo ">> Configurando generador con especificaciones normales (4 CPU, 16 GB RAM)..."
	@sed -i 's/^cpu            = [0-9][0-9]*/cpu            = 4096/' terraform/environments/student/generador/terraform.tfvars
	@sed -i 's/^memory         = [0-9][0-9]*/memory         = 16384/' terraform/environments/student/generador/terraform.tfvars
	@echo ">> Aplicando cambios en Terraform..."
	$(MAKE) generador-init
	$(MAKE) generador-plan
	$(MAKE) generador-apply
	@echo ">> Forzando actualización del servicio ECS..."
	@aws ecs update-service --cluster cluster_g3_MAIA --service generador-svc --force-new-deployment --region $(REGION) --output json | jq -r '.service | "Deployment iniciado: \(.deployments[0].id)\nEstado: \(.deployments[0].rolloutState)\nTask Definition: \(.taskDefinition)"' || \
	  aws ecs update-service --cluster cluster_g3_MAIA --service generador-svc --force-new-deployment --region $(REGION) --output text --query 'service.serviceName' | xargs -I {} echo "Deployment iniciado para servicio: {}"
	@echo ">> Redeploy con especificaciones normales iniciado. El servicio se actualizará en unos minutos."
	@echo ">> Verifica el estado con: make generador-status"

redeploy-clasificador:
	@echo ">> Reconstruyendo imagen Docker del clasificador-api..."
	$(MAKE) build-clasificador-api-image
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imagen a ECR..."
	$(MAKE) push-clasificador-api-image
	@echo ">> Forzando actualización del servicio ECS..."
	@aws ecs update-service --cluster cluster_g3_MAIA --service clasificador-api-svc --force-new-deployment --region $(REGION) --output json | jq -r '.service | "Deployment iniciado: \(.deployments[0].id)\nEstado: \(.deployments[0].rolloutState)\nTask Definition: \(.taskDefinition)"' || \
	  aws ecs update-service --cluster cluster_g3_MAIA --service clasificador-api-svc --force-new-deployment --region $(REGION) --output text --query 'service.serviceName' | xargs -I {} echo "Deployment iniciado para servicio: {}"
	@echo ">> Redeploy iniciado. El servicio se actualizará en unos minutos."
	@echo ">> Verifica el estado con: make clasificador-status"

redeploy-web:
	@echo ">> Reconstruyendo imagen Docker del web con endpoints actualizados..."
	$(MAKE) build-web-image
	@echo ">> Haciendo login a ECR..."
	$(MAKE) ecr-login
	@echo ">> Subiendo imagen a ECR..."
	$(MAKE) push-web-image
	@echo ">> Forzando actualización del servicio ECS..."
	@aws ecs update-service --cluster cluster_g3_MAIA --service web-svc --force-new-deployment --region $(REGION) --output json | jq -r '.service | "Deployment iniciado: \(.deployments[0].id)\nEstado: \(.deployments[0].rolloutState)\nTask Definition: \(.taskDefinition)"' || \
	  aws ecs update-service --cluster cluster_g3_MAIA --service web-svc --force-new-deployment --region $(REGION) --output text --query 'service.serviceName' | xargs -I {} echo "Deployment iniciado para servicio: {}"
	@echo ">> Redeploy iniciado. El servicio se actualizará en unos minutos."
	@echo ">> Verifica el estado con: make web-status"

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

stop-clasificador:
	@echo ">> Deteniendo servicio clasificador (preservando imagen en ECR)..."
	$(MAKE) destroy-clasificador
	@echo ">> Servicio detenido. La imagen en ECR se mantiene intacta."
	@echo ">> Para restaurar, ejecuta: make restore-clasificador"

restore-metricas:
	@echo ">> Restaurando servicio de métricas desde imagen existente en ECR..."
	@echo ">> Asumiendo que registry, VPC, ECS y LB ya existen..."
	@echo ">> NO se reconstruirá ni se empujará la imagen (usando imagen existente en ECR)..."
	$(MAKE) metricas-init
	$(MAKE) metricas-plan
	$(MAKE) metricas-apply
	$(MAKE) show_endpoints
	@echo ">> Servicio restaurado. Verifica el estado con: make metricas-status"

restore-generador:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make restore-generador MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  exit 1; \
	fi
	@echo ">> Restaurando servicio generador desde imagen existente en ECR..."
	@echo ">> Asumiendo que registry, VPC, ECS y LB ya existen..."
	@echo ">> NO se reconstruirá ni se empujará la imagen (usando imagen existente en ECR)..."
	@sed -i 's/MODEL_NAME = ".*"/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars || \
	  sed -i 's/MODEL_NAME = .*/MODEL_NAME = "$(MODEL_NAME)"/' terraform/environments/student/generador/terraform.tfvars
	$(MAKE) generador-init
	$(MAKE) generador-plan
	$(MAKE) generador-apply
	$(MAKE) show_endpoints
	@echo ">> Servicio restaurado. Verifica el estado con: make generador-status"

restore-clasificador:
	@echo ">> Restaurando servicio clasificador desde imagen existente en ECR..."
	@echo ">> Asumiendo que registry, VPC, ECS y LB ya existen..."
	@echo ">> NO se reconstruirá ni se empujará la imagen (usando imagen existente en ECR)..."
	$(MAKE) clasificador-api-init
	$(MAKE) clasificador-api-plan
	$(MAKE) clasificador-api-apply
	$(MAKE) show_endpoints
	@echo ">> Servicio restaurado. Verifica el estado con: make clasificador-status"

stop-web:
	@echo ">> Deteniendo servicio web (preservando imagen en ECR)..."
	$(MAKE) destroy-web
	@echo ">> Servicio detenido. La imagen en ECR se mantiene intacta."
	@echo ">> Para restaurar, ejecuta: make restore-web"

restore-web:
	@echo ">> Restaurando servicio web desde imagen existente en ECR..."
	@echo ">> Asumiendo que registry, VPC, ECS y LB ya existen..."
	@echo ">> NO se reconstruirá ni se empujará la imagen (usando imagen existente en ECR)..."
	@echo ">> NOTA: La imagen debe haber sido construida con los endpoints correctos..."
	$(MAKE) web-init
	$(MAKE) web-plan
	$(MAKE) web-apply
	$(MAKE) show_endpoints
	@echo ">> Servicio restaurado. Verifica el estado con: make web-status"

stopall:
	@echo ">> Deteniendo todos los servicios ECS (preservando NLB, cluster ECS e imágenes en ECR)..."
	@echo ">> NOTA: El NLB se mantiene activo (~\$0.54/día) para preservar los endpoints."
	@echo ">> Deteniendo servicio de métricas..."
	$(MAKE) destroy-metricas
	@echo ">> Deteniendo servicio generador..."
	$(MAKE) destroy-generador
	@echo ">> Deteniendo servicio clasificador..."
	$(MAKE) destroy-clasificador
	@echo ">> Deteniendo servicio web..."
	$(MAKE) destroy-web
	@echo ">> Todos los servicios ECS detenidos."
	@echo ">> El cluster ECS está ahora vacío (no consume recursos)."
	@echo ">> El NLB se mantiene activo (preserva los endpoints)."
	@echo ">> Las imágenes en ECR se mantienen intactas."
	@echo ">> Para restaurar los servicios, ejecuta: make restoreall MODEL_NAME=..."

restoreall:
	@if [ -z "$(MODEL_NAME)" ]; then \
	  echo "ERROR: MODEL_NAME no especificado. Ejemplo: make restoreall MODEL_NAME=meta-llama__Llama-3.2-3B-Instruct-6_epocas"; \
	  exit 1; \
	fi
	@echo ">> Restaurando todos los servicios ECS..."
	@echo ">> Asumiendo que registry, VPC, cluster ECS y NLB ya existen..."
	@echo ">> NO se reconstruirán ni se empujarán las imágenes (usando imágenes existentes en ECR)..."
	@echo ">> Verificando cluster ECS..."
	@if ! aws ecs describe-clusters --clusters cluster_g3_MAIA --region $(REGION) --query 'clusters[0].clusterName' --output text 2>/dev/null | grep -q "cluster_g3_MAIA"; then \
	  echo ">> Cluster ECS no existe, creándolo..."; \
	  $(MAKE) ecs-init; \
	  $(MAKE) ecs-plan; \
	  $(MAKE) ecs-apply; \
	else \
	  echo ">> Cluster ECS ya existe, saltando creación..."; \
	fi
	@echo ">> Verificando load balancer (NLB compartido)..."
	@if ! aws elbv2 describe-load-balancers --names metricas-nlb-shared --region $(REGION) --query 'LoadBalancers[0].LoadBalancerName' --output text 2>/dev/null | grep -q "metricas-nlb-shared"; then \
	  echo ">> NLB no existe, creándolo..."; \
	  $(MAKE) lb-init; \
	  $(MAKE) lb-plan; \
	  $(MAKE) lb-apply; \
	else \
	  echo ">> NLB ya existe, saltando creación (endpoints se mantienen)..."; \
	fi
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
	@echo ">> Restaurando servicio clasificador..."
	$(MAKE) clasificador-api-init
	$(MAKE) clasificador-api-plan
	$(MAKE) clasificador-api-apply
	@echo ">> Restaurando servicio web..."
	@echo ">> NOTA: El web requiere que la imagen en ECR haya sido construida con los endpoints correctos."
	@echo ">> Si los endpoints cambiaron, ejecuta 'make build-web-image && make push-web-image' antes de restaurar."
	$(MAKE) web-init
	$(MAKE) web-plan
	$(MAKE) web-apply
	@echo ">> Mostrando URLs de los servicios..."
	$(MAKE) show_endpoints
	@echo ">> Todos los servicios, load balancer y cluster ECS restaurados."
	@echo ">> Verifica el estado con: make metricas-status, make generador-status, make clasificador-status, make web-status"
