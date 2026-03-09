# Projeto dbt + Databricks - Guia de Configuração

Este documento descreve o processo completo de configuração de um ambiente de desenvolvimento dbt (Data Build Tool) utilizando o **motor Fusion**, integrado ao **Databricks** e à **extensão oficial do dbt para VS Code** . O case de negócio é um restaurante fictício chamado Jaffle Shop.

## Neste projeto será aprendido
- Carregar dados brutos (CSV) para um data warehouse
- Transformar esses dados usando SQL e o dbt
- Construir um pipeline de dados modular, testado e documentado
- Automatizar todo o processo com CI/CD (GitHub Actions)


## 📋 Pré-requisitos

- Conta no **Databricks** (Community Edition ou trial)
- **VS Code** instalado
- **PowerShell** (Windows) - para execução dos comandos
- **dbt Fusion** (motor de transformação)  - a engine que vai compilar e executar nossos modelos SQL

# 🚀 Configuração Inicial do Databricks

###  1. Upload dos Dados Brutos (CSV)
Os dados brutos do Jaffle Shop estão em arquivos CSV. Precisamos carregá-los no Databricks para que o dbt possa acessá-los.

Para cada arquivo CSV (customers, orders, payments, etc.):

1. No Databricks, clique em **"New"** > **"Add or upload data"**
2. Selecione **"Create or modify a table"**
3. Escolha o catálogo `raw` 
4. crie os schemas `jaffle_shop` para dados da loja e `stripe` para dados de pagamentos
4. Nomeie a tabela o prefixo `raw_` (ex: `raw_customers`, `raw_orders`)`- isso ajuda a identificar tabelas brutas
5. Repita para todos os arquivos

**Por que isso?** Estamos separando os dados brutos (raw) dos dados transformados.

### **2. Gerar Token de Acesso**
O token é a "chave" que permite ao dbt se autenticar no Databricks.

1. No Databricks, clique no ícone do usuário (canto superior direito)
2. Vá em **"Settings"** > **"Developer"** > **"Access Tokens"**
3. Clique em **"Generate new token"**
4. Dê um nome (ex: `dbt-token`) e copie o valor gerado (guarde em local seguro)

⚠️ Importante: O token só é mostrado uma vez. Se perder, precisará gerar outro.

-----

# 💻 Configuração do Ambiente Local

### **3. Configurar a Extensão do VS Code**
A extensão oficial do dbt para VS Code oferece recursos como:
- Syntax highlighting para SQL + Jinja
- Preview de dados diretamente no editor
- Visualização do DAG (linhagem dos dados)
- Autocomplete inteligente

1. Abra o VS Code
2. Instale a extensão **"dbt"** do publisher **"dbt Labs Inc"**
3. Abra a pasta do projeto (`File > Open Folder`)
4. Verifique na barra inferior se o nome do projeto aparece

### **4. Instalação do dbt Fusion CLI**
O dbt Fusion é a engine que vai executar nossos comandos. Diferente da extensão (que é a interface), o CLI é o "motor" propriamente dito.

### **4.1. Instalar o Fusion Engine**

Abra o **PowerShell como administrador** e execute:

```
irm https://public.cdn.getdbt.com/fs/install/install.ps1 | iex
```

Para verificar instalação, feche e reabra o PowerShell(para atualizar as variáveis de ambiente), então execute:
```
dbtf --version
```
----
# 📁 Criação do Projeto dbt

### **5. Inicializar o Projeto**

- Navegue até a pasta de projetos
- Inicie com `dbtf init`

O comando init inicia um assistente interativo. Responda conforme a tabela:

| **Pergunta** | **Resposta** |
| --- | --- |
| `Enter a name for your project` | `jaffle_shop` |
| `Which adapter would you like to use?` | `databricks` |
| `Host` | `dbc-xxxx-xxxx.cloud.databricks.com` (sem https://) |
| `HTTP Path` | `/sql/1.0/warehouses/xxxx` (copiado do Databricks) |
| `Schema` | `jaffle_shop` |
| `Catalog`  | `raw` |
| `Authentication method` | `Personal Access Token` |
| `Personal Access Token` | [cole o token gerado] |

### **6. Configuração dos Arquivos YAML**
O arquivo de perfil é criado automaticamente em `C:\Users\SeuUsuario\.dbt\profiles.yml`, ele contém as credenciais de conexão:

```
jaffle_shop:
  target: dev
  outputs:
    dev:
      type: databricks
      host: dbc-xxxx-xxxx.cloud.databricks.com
      http_path: /sql/1.0/warehouses/xxxx
      token: [seu-token]
      catalog: raw
      schema: jaffle_shop
      threads: 4
```

### **7. Testar a Conexão**

Antes de executar qualquer modelo, vamos verificar se a conexão está funcionando:

```
cd C:\...\jaffle_shop
dbtf debug
```
Se tudo estiver correto, você verá "All checks passed!" no final da execução.

### **8. Executar os Modelos**
Com a conexão testada, vamos construir os modelos:

```
dbtf run
```

Este comando:

- Compila os modelos SQL
- Executa no Databricks na ordem correta (respeitando dependências)
- Cria as views e tabelas conforme configurado

Para executar tudo (seeds, modelos, testes) em uma só vez:
```
dbtf build
```

### **9. Criando secrets no GitHub**
Para que o GitHub Actions possa acessar seu Databricks de forma segura, precisamos armazenar as credenciais como "secrets" (variáveis criptografadas).

No seu repositório do GitHub:

- Vá em Settings (Configurações)

- No menu lateral, clique em "Secrets and variables" > "Actions" 

- Clique no botão "New repository secret"

- Adicione cada um dos segredos abaixo, um por um:

| **Nome do Secret** | **Onde encontrar** |
| --- | --- |
| `DATABRICKS_HOST` | URL do seu workspace (sem https://) |
| `DATABRICKS_HTTP_PATH` | Databricks > SQL Warehouse > Connection Details |
| `DATABRICKS_TOKEN` | Gerar novo em User Settings > Developer > Access Tokens |
| `DATABRICKS_CATALOG` | Nome do catálogo (geralmente `raw` ou `hive_metastore`) |
| `DATABRICKS_SCHEMA` | Schema padrão do seu projeto |

### **10.Deploy**
O GitHub Actions vai automatizar a execução do dbt sempre que houver um push no repositório (ou em horário agendado). Esse processo garante qualidade e atualização contínua dos dados.

- Crie as pastas `.github\workflows`  na raiz do seu projeto e dentro dele o arquivo `build.yaml` com o seguinte código:
```
name: workflow_dbt-build

# Executa diariamente as 5 da manhã
on:
    push:
        branches:
            - main
    schedule:
        - cron: '0 5 * * *'        

env:    
    DBT_PROFILES_DIR: ~/.dbt
    PYTHON_VERSION: '3.10'

jobs:
    #Job 1: Build 
    build:
        runs-on: ubuntu-latest
     
        steps:
        - name: Checkout app code
          uses: actions/checkout@v4   # Baixa o código do repositório
     
        - name: Set up Python
          uses: actions/setup-python@v4
          with:
            python-version: ${{ env.PYTHON_VERSION }}

        - name: Install dbt
          run: pip install dbt-databricks    

        - name: Login to DataBricks    
          env:
            DATABRICKS_HOST: ${{ secrets.DATABRICKS_HOST }}
            DATABRICKS_HTTP_PATH: ${{ secrets.DATABRICKS_HTTP_PATH }}
            DATABRICKS_TOKEN: ${{ secrets.DATABRICKS_TOKEN }}
            DATABRICKS_CATALOG: ${{ secrets.DATABRICKS_CATALOG }}
            DATABRICKS_SCHEMA: ${{ secrets.DATABRICKS_SCHEMA }}
          run: |
            #Cria arquivo profiles.yml com o conteúdo entre EOF e EOF
            mkdir -p ${{ env.DBT_PROFILES_DIR }}
            cat > ${{ env.DBT_PROFILES_DIR }}/profiles.yml << EOF
            jaffle_shop:
                target: dev
                outputs:
                dev:
                    type: databricks
                    host: ${{ env.DATABRICKS_HOST }}
                    http_path: ${{ env.DATABRICKS_HTTP_PATH }}
                    token: ${{ env.DATABRICKS_TOKEN }}
                    catalog: ${{ env.DATABRICKS_CATALOG }}
                    schema: ${{ env.DATABRICKS_SCHEMA }}
                    threads: 4
            EOF   
            
        - name: Run dbt deps
          run: dbt deps    

        - name: Run dbt build
          run: dbt build    
```
- Agora adicione ao repositório as novas mudanças, elas  acionarão o GitHub Actions automaticamente

```
git add .github/workflows/workflow_dbt-build.yml
git commit -m "Adiciona workflow de CI/CD com segredos"
git push origin main 
```

Para acompanhar a execução:

- Vá até seu repositório no GitHub
- Clique na aba "Actions"
- Você verá o workflow sendo executado
- Clique nele para ver os logs em tempo real


----

## 📊 Verificando os Resultados

No Databricks: Verificar se as tabelas foram criadas/atualizadas:

```
SHOW TABLES IN raw.jaffle_shop;
SELECT * FROM raw.jaffle_shop.dim_customers LIMIT 10;
```

- No GitHub Actions: Conferir os logs para ver se todos os testes passaram
- Na documentação do dbt: Gerar e visualizar a documentação interativa:

```
dbt docs generate
dbt docs serve
```
----
## Outros conceitos Importantes utilizados no projeto
| **Conceito** | **O que é** | **Por que importa** |
| --- | --- | --- |
| **Source** | Tabelas brutas no warehouse | Centraliza a configuração e documentação dos dados de origem |
| **Staging** | Modelos intermediários que limpam dados | Criam uma camada de confiança entre o raw e os marts |
| **Marts** | Modelos finais para análise | Prontos para serem consumidos por BI tools |
| **DAG** | Grafo de dependências entre modelos | Mostra visualmente como os dados fluem |


Projeto configurado em: 08/03/2026
Versão do dbt Fusion: 2.0.0-preview.126
Plataforma de dados: Databricks