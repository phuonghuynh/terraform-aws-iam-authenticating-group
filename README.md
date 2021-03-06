# Terraform Module For Dynamically Managing IAM Groups

This module allows you to dynamically manage IAM group membership through an authenticated HTTPS endpoint.

This module is available on the [Terraform Registry](https://registry.terraform.io/modules/riboseinc/iam-authenticating-group)

### Components

    1. API Gateway that performs authorization.

    2. On-demand Lambda function (linked to API Gateway method `POST|DELETE /membership`): to add/remove IAM group memberships on-demand

    3. Continuous Lambda function: to clean up expired memberships


### On-demand Lambda Function: Adding/Removing IAM Group Membership

This is the Lambda function that runs `add-user-to-group` and
`remove-user-from-group` on-demand on the given IAM group.

Steps:

    1. Authenticate the user via AWS IAM (Signature Version 4).
       Eligibility to authenticate is set in a policy outside of this module.
       The user will provide an AWS v4 signature for authentication.
       Return **403** if not authorized.

    3. If the request is a `POST /membership`
       -  The function will issue a `add-user-to-group` action for the user. 
       -  An inline `fake-policy-[group_name]` is attached to user and used as a rule 
           that indicates the "time" that this membership was added.
       -  Return **200**.

    4. If the request is a `DELETE /membership`
       -  If the user is in the IAM group, issue a `remove-user-from-group` on it
       -  If the user is not in the IAM group, do nothing
       -  Return **200**.
    
    5. If any request has errors, e.g. a user / a group not found, internal API failed.
       -  Return **400** and error details
    
    6. Return **500** for other errors

    7. Done.

### Continuous Lambda Function: Removing Rules

This is the Lambda function that runs `remove-user-from-group` on the
given IAM group on user access expiry.

This AWS Lambda function runs every X seconds, and its sole task is to clean
out the IAM group that has stale membership.

Steps:

    1. The function will describe all rules in the given IAM group.

    2. For every rule, it will check the time of last update.
       -  If the elapsed time is less than the configured X seconds, don't do anything.
       -  If the elapsed time is more than the configured X seconds, it means that the
          rule has expired, and it should execute `revoke-iam-group` on it.
          (e.g., if all rules are expired, the IAM group should now contain no rules)

    3. Done.


### Sample Usage

Check out [examples](https://github.com/riboseinc/terraform-aws-iam-authenticating-group/tree/master/examples) for more details


#### Provider Config
  
  - Arguments will be exposed to S3 Bucket with name `${bucket_name}/args.json`. User can update it with new values. 
  
  - Where should this API deployed to, more info [aws](https://www.terraform.io/docs/providers/aws)

```hcl-terraform
provider "aws" {
  region  = "us-west-2"
}
```


#### Inline Config

```hcl-terraform
module "dynamic-iamgroup" {
  source = "riboseinc/iam-authenticating-group/aws"

  name           = "example-dynamic-iam-groups"
  bucket_name    = "example-dynamic-iam-groups-bucket"
  description    = "example usage of terraform-aws-authenticating-iam"
  
  # in seconds
  time_to_expire = 300
  
  # CloudWatch log level "INFO" or "DEBUG", default is "INFO"
  log_level = "INFO" 
  
  iam_groups     = [
    {
      "group_name" = "group_name_1",
      "user_names" = [
        "user_name_1",
        "user_name_2"
      ]
    },
    {
      "group_name" = "group_name_2",
      "user_names" = [
        "user_name_1",
        "user_name_2"
      ]
    }
  ]
}
```

#### JSON file Config
```hcl-terraform
module "dynamic-iam-group" {
  source         = "../../"
  name           = "example-dynamic-iam-groups"
  bucket_name    = "example-dynamic-iam-groups-bucket"
  description    = "example usage of terraform-aws-authenticating-iam"
  time_to_expire = 300
  log_level = "INFO"
  iam_groups     = ["${file("iam_groups.json")}"]
}
```

#### Policy Config

```hcl-terraform
resource "aws_iam_policy" "this" {
  description = "Policy Developer IAM Access"
  policy      = "${data.aws_iam_policy_document.access_policy_doc.json}"
}

data "aws_iam_policy_document" "access_policy_doc" {
  statement {
    effect    = "Allow"
    actions   = [
      "execute-api:Invoke"
    ]
    resources = [
      "${module.dynamic-iamgroup.execution_resources}"]
  }
}
```


#### Some outputs
```hcl-terraform
output "dynamic-iamgroup-api-invoke-url" {
  value = "${module.dynamic-iamgroup.invoke_url}"
}
```

### Limitations on IAM Entities and Objects

AWS IAM has certain [limits](https://docs.aws.amazon.com/IAM/latest/UserGuide/reference_iam-limits.html) that affect this module's operations, including:

  - A user can only have max 10 IAM groups
  - A user/group/role can only have max 10 IAM policies
  
Some works around:
  
  - Use a separate user account if reached 10 IAM groups

### Bash to execute the API

Check out [aws-authenticating-secgroup-scripts](https://github.com/riboseinc/aws-iam-authenticating-group-scripts)

