# Notes

## 0. Create the stack in AWS (Terminal 1)

https://us-east-1.console.aws.amazon.com/ec2/v2/home?region=us-east-1#Instances:instanceState=running

```
tf init && tf apply --var "github_user=YOUR_GH_USER_ID"
```

## 1. Clone the repo

```
git clone --depth 1 git@github.com:upcschool-cloud-arch/contenido.git
```
