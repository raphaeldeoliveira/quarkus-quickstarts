#!/bin/bash

# Este comando faz com que o script pare imediatamente se qualquer comando falhar.
set -e

# O nome do ambiente alvo (des ou prd) é o primeiro argumento
ENVIRONMENT=$1

APP_NAME="getting-started"
DOCKER_USER="raphaelcarvalho30"

# --- 1. CONFIGURAÇÃO INICIAL (feita uma vez no começo) ---
echo "=================================================="
echo "          INICIANDO PIPELINE DE CI/CD             "
echo "        Ambiente Alvo: $ENVIRONMENT                "
echo "=================================================="

# --- 2. OBTER A VERSÃO DA APLICAÇÃO ---
echo "Passo 1: Lendo a versão do pom.xml..."
APP_VERSION=$(./mvnw help:evaluate -Dexpression=project.version -q -DforceStdout)
echo "Versão da aplicação encontrada: $APP_VERSION"

# --- 3. COMPILAR APLICAÇÃO ---
echo "Passo 2: Compilando a aplicaçao Quarkus..."
./mvnw clean package

# --- 4. CONSTRUIR A IMAGEM DOCKER ---
echo "Passo 3: Construindo a imagem Docker..."
docker build -t "$DOCKER_USER/$APP_NAME:$APP_VERSION" .
docker tag "$DOCKER_USER/$APP_NAME:$APP_VERSION" "$DOCKER_USER/$APP_NAME:latest"
echo "Imagem Docker '$DOCKER_USER/$APP_NAME' construída e tagueada com sucesso."

# --- 5. IMPLANTAR NO AMBIENTE ---
echo "Passo 4: Implantando no ambiente $ENVIRONMENT..."
minikube kubectl -- create namespace "$ENVIRONMENT" || true
minikube kubectl -- apply -f "./kubernetes/$ENVIRONMENT/deployment.yaml"
minikube kubectl -- apply -f "./kubernetes/$ENVIRONMENT/service.yaml"

echo "Aguardando o Deployment 'getting-started-$ENVIRONMENT' ficar pronto..."
minikube kubectl -- rollout status deployment/"$APP_NAME"-"$ENVIRONMENT" --namespace="$ENVIRONMENT"
echo "Implantação no ambiente $ENVIRONMENT concluída com sucesso!"

# --- 6. EXECUTAR TESTES DE VALIDAÇÃO (Sem a flag --url para simular o loop) ---
echo "Passo 5: Executando validação de saude do serviÃ§o $ENVIRONMENT..."
# Este comando ficará em loop, conforme sua instrução.
minikube kubectl -- service "$APP_NAME"-service-"$ENVIRONMENT" --namespace="$ENVIRONMENT"

# Se o script chegar até aqui, é porque algo está errado
echo "=================================================="
echo "          ERRO NA LÓGICA DE LOOP!                 "
echo "=================================================="