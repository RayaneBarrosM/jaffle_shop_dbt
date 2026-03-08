# Projeto dbt + Databricks - Guia de Configuração

Este documento descreve o processo completo de configuração de um ambiente de desenvolvimento dbt (Data Build Tool) utilizando o **motor Fusion**, integrado ao **Databricks** e à **extensão oficial do dbt para VS Code** . O case de negócio é um restaurante fictício chamado Jaffle Shop.


## 📋 Pré-requisitos

- Conta no **Databricks** (Community Edition ou trial)
- **VS Code** instalado
- **PowerShell** (Windows) - para execução dos comandos
- **dbt Fusion** (motor de transformação)


###  1. Upload dos Dados Brutos (CSV)

Para cada arquivo CSV (customers, orders, payments, etc.):

1. No Databricks, clique em **"New"** > **"Add or upload data"**
2. Selecione **"Create or modify a table"**
3. Escolha o catálogo `raw` e crie o schema `jaffle_shop` (para dados da loja) ou `stripe` (para pagamentos)
4. Nomeie a tabela conforme o arquivo (ex: `raw_customers`, `raw_orders`)
5. Repita para todos os arquivos

### **1.2. Gerar Token de Acesso**

1. No Databricks, clique no ícone do usuário (canto superior direito)
2. Vá em **"Settings"** > **"Developer"** > **"Access Tokens"**
3. Clique em **"Generate new token"**
4. Dê um nome (ex: `dbt-token`) e copie o valor gerado (guarde em local seguro)

### **2. Configurar a Extensão do VS Code**

1. Abra o VS Code
2. Instale a extensão **"dbt"** do publisher **"dbt Labs Inc"**
3. Abra a pasta do projeto (`File > Open Folder`)
4. Verifique na barra inferior se o nome do projeto aparece

### **3. Instalação do dbt Fusion CLI**

### **3.1. Instalar o Fusion Engine**

Abra o **PowerShell como administrador** e execute:

```
irm https://public.cdn.getdbt.com/fs/install/install.ps1 | iex
```

Para erificar instalação, feche e abra o powerShell
```
dbtf --version
```
### **4. Criação do Projeto dbt**

- Navegue até a pasta de projetos
- Inicie com `dbtf init`

| **Pergunta** | **Resposta** |
| --- | --- |
| `Enter a name for your project` | `jaffle_shop` |
| `Which adapter would you like to use?` | `databricks` |
| `Host` | `dbc-xxxx-xxxx.cloud.databricks.com` (sem https://) |
| `HTTP Path` | `/sql/1.0/warehouses/xxxx` (copiado do Databricks) |
| `Schema` | `jaffle_shop` |
| `Catalog` (optional) | `raw` (ou `hive_metastore`) |
| `Authentication method` | `Personal Access Token` |
| `Personal Access Token` | [cole o token gerado] |

### **5. Configuração dos Arquivos YAML**
O arquivo de perfil é criado automaticamente em `C:\Users\SeuUsuario\.dbt\profiles.yml`:
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

### **6. Testar a Conexão**
```
cd C:\...\jaffle_shop
dbtf debug
```

### **7. Executar os Modelos**
```
dbtf run
```
### **8.Criando secrets**
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

### **9.Deploy**
- Crie as pastas `.github\workflows` dentro dele o arquivo `build.yaml`
- E cole o seguinte código
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
- Agora adicione ao repositório as novas mudanças, elas ativarão o gitactions automaticamente

```
git add .github/workflows/workflow_dbt-build.yml
git commit -m "Adiciona workflow de CI/CD com segredos"
git push origin main 
```