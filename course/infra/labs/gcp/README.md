# Google Cloud: CLI and project setup

Use an instructor-provided or otherwise approved Google Cloud project. The session's live Azure/GCP demonstrations run in instructor accounts; students can follow the [offline comparison](../azure-gcp/README.md) without cloud credentials or resources.

Labs: [00 · Terraform state in Cloud Storage](00-terraform-state/README.md), [01 · Compute Engine basics and SSH](01-compute-basics/README.md), [02 · WordPress and Cloud SQL](02-wordpress/README.md), [03 · WordPress module](03-wordpress-module/README.md), and [04 · WordPress managed instance group](04-wordpress-mig/README.md).

## Install the Google Cloud CLI

- **macOS:** Follow Google's [macOS installation instructions](https://cloud.google.com/sdk/docs/install#mac) for your processor and shell. Open a new terminal after updating `PATH`.
- **Windows:** Follow Google's [Windows installation instructions](https://cloud.google.com/sdk/docs/install#windows) and open a new PowerShell window after installation.

Verify the installation and sign in through the browser:

```sh
gcloud version
gcloud init
```

`gcloud init` lets you choose an account and project. Use your approved identity; do not share credentials or browser authentication links.

## Select and verify a project

In [Google Cloud Console](https://console.cloud.google.com/projectselector2/home/dashboard), select the approved project. If you must create one, use **New Project**, choose the authorized organization/folder if applicable, and obtain a globally unique project ID. Project creation and billing linkage require appropriate permissions; follow Google's [project creation guide](https://cloud.google.com/resource-manager/docs/creating-managing-projects). Do not create a project in a managed organization without authorization.

In a terminal or PowerShell, replace `PROJECT_ID` with the actual project ID (not its display name):

```sh
gcloud config set project PROJECT_ID
gcloud config list
gcloud projects describe PROJECT_ID
```

Check the active account and project before any live work:

```sh
gcloud auth list
gcloud config get-value project
```

Confirm the project has an approved billing account in **Billing → My projects**. See [Google's billing guide](https://cloud.google.com/billing/docs/how-to/modify-project).

## Sign in for Terraform

Terraform uses **Application Default Credentials (ADC)**, which are separate from the `gcloud` CLI login. Sign in again and select the intended account in the browser:

```sh
gcloud auth application-default login
```

If Terraform reports a different account or a permission error, check for `GOOGLE_APPLICATION_CREDENTIALS` or service-account impersonation overriding ADC. The account needs permissions in the selected project. Never share credentials or authentication links.

Set the Terraform provider's project from the active `gcloud` configuration.

macOS:

```sh
export GOOGLE_CLOUD_PROJECT="$(gcloud config get-value project)"
```

Windows PowerShell:

```powershell
$env:GOOGLE_CLOUD_PROJECT = gcloud config get-value project
```

Confirm the active project is approved. Repeat this step in each new terminal or after changing the active project; the environment variable does not update automatically.

## Enable required APIs

Google Cloud services require their APIs to be enabled in the project. Check the lab prerequisites first; enabling services can require Service Usage permissions and must be authorized by the project owner. For the Compute Engine and OS Login demonstration, replace `PROJECT_ID` and run:

```sh
gcloud services enable compute.googleapis.com oslogin.googleapis.com --project=PROJECT_ID
gcloud services list --enabled --project=PROJECT_ID
```

Alternatively, use **APIs & Services → Library** in Google Cloud Console and enable the required APIs in the selected project. See [Google's API enablement guide](https://cloud.google.com/service-usage/docs/enable-disable). API enablement alone does not grant OS Login IAM permissions or guarantee that organization policies allow the lab. Service usage can incur charges; do not disable shared APIs during lab cleanup.

Review costs and budgets before deploying. Billing data may be delayed, and budgets/alerts **do not automatically stop spending**. Delete only resources created for the exercise, following the lab's cleanup instructions; never delete a shared project or billing account.
