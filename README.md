# Terraform AWS API Gateway Lambda Demo

A small example of a Terraform module for creating a HTTP AWS API Gateway that points to a Lambda function at a specific URL path.

The blog post covering this in greater depth can be found [here](https://nathankuik.com/posts/terraform-aws-api-gateway-lambda/).

## Limitations

Keep in mind that the code included there doesn't really take into consideration multiple routes with multiple Lambdas. Examples of such modules can be found relatively easily through a web search.
