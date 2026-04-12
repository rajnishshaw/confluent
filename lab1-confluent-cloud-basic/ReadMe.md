Before you can run this Terraform section, ensure you have the following software:

1. A user account on Confluent Cloud
2. Local install of Terraform
3. Local install of the Confluent CLI
4. Create an API Key using Confluent CLI:

```bash
confluent login
confluent api-key create --resource cloud --description "API for terraform"
```

It may take a couple of minutes for the API key to be ready. Save the API key and secret. The secret is not retrievable later.

```bash
API Key    | <yourkey>
```
```bash                                         
API Secret | <yoursecret>
```
```bash                                     
cat > terraform.tfvars <<EOF
confluent_cloud_api_key = "{Cloud API Key}"
confluent_cloud_api_secret = "{Cloud API Key Secret}"
use_prefix = "{Your Name}"
EOF
```

Run the following commands to provision the environment
```bash       
terraform init
terraform plan -out tfplan
terraform apply tfplan
```
Clean Up
```bash       
terraform destroy
```