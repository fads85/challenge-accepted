# challenge-accepted
Requerimentos:
terraform
conta registrada AWS

Clone este repositório, mude para o diretório criado e execute o comando:  
terraform init

É necessário uma access key e secret key de um usuário com permissões para a execução desse template na AWS.
Exitem 3 maneiras para você declarar a access key e secret key, abaixo está descrita as 3 maneiras na ordem de precedência.
Exportar como variável de ambiente:  
$ export AWS_ACCESS_KEY_ID="anaccesskey"  
$ export AWS_SECRET_ACCESS_KEY="asecretkey"  
$ export AWS_DEFAULT_REGION="us-west-2"  

Atribuir as variaveis no arquivo network.tf  
provider "aws" {  
  region     = "us-west-2"  
  access_key = "anaccesskey"  
  secret_key = "asecretkey"  
}  

Ou ter instalado o aws cli e executado o comando:  
aws configure  

Para verificar o que será criado antes da aplicação desse template:  
terraform plan  

Para a execução desse template:  
terraform init  
