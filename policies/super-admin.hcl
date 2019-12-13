# This policy gives access rights similar to the root token but with the 
# advantage of providing the ability to audit each and every transactions
# as the root token access are not included
path "*"
{
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
