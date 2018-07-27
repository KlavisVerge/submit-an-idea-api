# submit-an-idea-api
one-time: terraform init
zip: may exclude terraform...need to move it to s3 instead of local
yarn install --production  to keep zip smaller. Need to CI/CD this.
generate zip

get properties:
aws apigateway get-rest-apis
aws apigateway get-resources --rest-api-id XXX

deploy:
terraform validate
terraform apply -auto-approve

aws apigateway create-deployment --rest-api-id XXX --stage-name api