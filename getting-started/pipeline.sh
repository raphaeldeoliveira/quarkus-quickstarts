#!/bin/bash

# Este comando faz com que o script pare imediatamente se qualquer comando falhar.
set -e

# O nome do ambiente alvo (des ou prd) é o primeiro argumento
ENVIRONMENT=$1

APP_NAME="getting-started"
DOCKER_USER="raphaelcarvalho30"

echo "=================================================="
echo "          INICIANDO PIPELINE DE CI/CD             "
echo "        Ambiente Alvo: $ENVIRONMENT                "
echo "=================================================="

# O Jenkins já fez o clone, então não precisamos clonar de novo.

# --- 1. OBTER A VERSÃO DA APLICAÇÃO ---
echo "Passo 1: Lendo a versão do pom.xml..."
APP_VERSION=$(./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout)
echo "Versão da aplicação encontrada: $APP_VERSION"

# --- 2. CONSTRUIR A IMAGEM DOCKER ---
echo "Passo 2: Compilando e construindo a imagem Docker..."
./mvnw clean package -Dquarkus.container-image.build=true -Dquarkus.container-image.group=$DOCKER_USER -Dquarkus.container-image.tag=$APP_VERSION
docker tag "$DOCKER_USER/$APP_NAME:$APP_VERSION" "$DOCKER_USER/$APP_NAME":latest
echo "Imagem Docker '$DOCKER_USER/$APP_NAME' construída e tagueada com sucesso."

# --- 3. EXECUTAR TESTES UNITÁRIOS ---
echo "Passo 3: Executando testes unitários..."
./mvnw test

# --- 4. IMPLANTAR NO AMBIENTE ---
echo "Passo 4: Implantando no ambiente $ENVIRONMENT..."
minikube kubectl -- create namespace "$ENVIRONMENT" || true
minikube kubectl -- apply -f "./kubernetes/$ENVIRONMENT/"

echo "Aguardando o Deployment 'getting-started-$ENVIRONMENT' ficar pronto..."
minikube kubectl -- rollout status deployment/"$APP_NAME"-"$ENVIRONMENT" --namespace="$ENVIRONMENT"
echo "Implantação no ambiente $ENVIRONMENT concluída com sucesso!"

# --- 5. EXECUTAR TESTES DE VALIDAÇÃO ---
echo "Passo 5: Executando validação de saúde do serviço $ENVIRONMENT..."
SERVICE_URL=$(minikube kubectl -- service "$APP_NAME"-service-"$ENVIRONMENT" --namespace="$ENVIRONMENT" --url)

echo "URL do serviço: $SERVICE_URL"

if curl --fail --silent "$SERVICE_URL/hello"; then
  echo "Validação de saúde do serviço $ENVIRONMENT: SUCESSO!"
else
  echo "Validação de saúde do serviço $ENVIRONMENT: FALHA!"
  exit 1
fi

echo "=================================================="
echo "          PIPELINE CONCLUÍDA COM SUCESSO!         "
echo "=================================================="