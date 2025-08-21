#!/bin/bash

# Este comando faz com que o script pare imediatamente se qualquer comando falhar.
set -e

APP_NAME="getting-started"
DOCKER_USER="raphaelcarvalho30"
APP_VERSION="1.0.0-SNAPSHOT" # Usando SNAPSHOT para este exemplo

echo "=================================================="
echo "          INICIANDO PIPELINE DE PRD               "
echo "=================================================="

# --- 1. OBTER A VERSÃO DA APLICAÇÃO ---
echo "Passo 1: Lendo a versÃ£o do pom.xml..."
APP_VERSION=$(./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout)
echo "VersÃ£o da aplicaÃ§Ã£o encontrada: $APP_VERSION"

# --- 2. COMPILAR APLICAÇÃO ---
echo "Passo 2: Compilando a aplicaÃ§ao Quarkus..."
./mvnw clean package

# --- 3. EXECUTAR TESTES UNITÁRIOS ---
echo "Passo 3: Executando testes unitários..."
./mvnw test

# --- 4. CONSTRUIR E ENVIAR A IMAGEM DOCKER ---
echo "Passo 4: Construindo e enviando a imagem Docker..."
docker build -t "$DOCKER_USER/$APP_NAME:$APP_VERSION-prd" .
docker push "$DOCKER_USER/$APP_NAME:$APP_VERSION-prd"

# --- 5. IMPLANTAR NO AMBIENTE PRD ---
echo "Passo 5: Implantando no ambiente PRD..."
minikube kubectl -- create namespace prd || true
minikube kubectl -- apply -f ./kubernetes/prd/

echo "Aguardando o Deployment 'getting-started-prd' ficar pronto..."
minikube kubectl -- rollout status deployment/getting-started-prd -n prd
echo "Implantação no ambiente PRD concluída com sucesso!"

# --- 6. EXECUTAR TESTES DE VALIDAÇÃO ---
echo "Passo 6: Executando validação de saude do serviÃ§o PRD..."
SERVICE_URL=$(minikube kubectl -- service getting-started-service-prd --namespace=prd --url)
echo "URL do serviço: $SERVICE_URL"

if curl --fail --silent "$SERVICE_URL/hello"; then
  echo "Validação de saúde do serviço PRD: SUCESSO!"
else
  echo "Validação de saúde do serviço PRD: FALHA!"
  exit 1
fi
echo "=================================================="
echo "          PIPELINE PRD CONCLUÍDA!                 "
echo "=================================================="