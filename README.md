# Week 07 – Continuous Integration with GitHub Actions

> **SIT722 Task 10.3HD:** this repository now also includes a zero-downtime blue/green deployment of `course-service` to Azure App Service. See **[BLUE_GREEN.md](BLUE_GREEN.md)** for setup and demo steps.

In this example, we extend the application from **Week 06 – Example 01** by introducing a Continuous Integration (CI) pipeline using GitHub Actions.

The CI pipeline will:

1. Run automated tests for all backend services.
2. Continue only if all tests pass.
3. Build Docker images for all backend services and the frontend.
4. Authenticate with Microsoft Azure.
5. Push the Docker images to Azure Container Registry (ACR).

---
## 1. Fork the Repository

Log into GitHub, then go to this weeks repository [https://github.com/sit722-devops/week07](https://github.com/sit722-devops/week07) and __Fork__ this into your account.

![Fork Repository](github-fork.png)

After forking the repository, clone your fork to your local machine.

```bash
git clone <YOUR-FORKED-REPOSITORY-URL>
```

Navigate to the project directory.

```bash
cd <PROJECT-DIRECTORY>
```
---

## 2. Create the Required Azure Infrastructure

Make sure the _Azure Container Registry_ has been successfully created before configuring the CI pipeline.

---

## 3. Create a Service Principal

_GitHub Actions_ requires permission to authenticate with Azure and push Docker images to Azure Container Registry.

Create a _Microsoft Entra application and service principal_ by following the official Microsoft documentation:

[https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal](https://learn.microsoft.com/en-us/entra/identity-platform/howto-create-service-principal-portal
)

When creating the service principal, make sure you record the following values:

- Application (Client) ID
- Directory (Tenant) ID
- Client Secret Value
- Azure Subscription ID

> **Important:** Copy the **Client Secret Value** when it is created. The secret value is displayed only once.

---

## 4. Assign ACR Permission

The service principal must have permission to push Docker images to Azure Container Registry.

In the Azure Portal:

1. Open your **Azure Container Registry**.
2. Go to **Access control (IAM)**.
3. Select **Add role assignment**.
4. Assign the appropriate role that allows the service principal to push images to the registry (i.e., `Contributor`).
5. Select the service principal created in the previous step.
6. Complete the role assignment.

---

## 5. Create GitHub Repository Secret

Open your GitHub repository and go to:

**Settings → Secrets and variables → Actions → Secrets**

Create the following **Repository Secret**:

```text
AZURE_CREDENTIALS
```

Use the following structure:

```json
{
  "clientId": "YOUR_CLIENT_ID",
  "clientSecret": "YOUR_CLIENT_SECRET",
  "subscriptionId": "YOUR_SUBSCRIPTION_ID",
  "tenantId": "YOUR_TENANT_ID"
}
```

Replace each value with the information from your Azure service principal and subscription.

> Never commit Azure credentials or client secrets to the GitHub repository.

---

## 6. Create GitHub Repository Variables

Go to:

**Settings → Secrets and variables → Actions → Variables**

Create the following **Repository Variables**:

```text
ACR_NAME
```

Set the value to the name of your Azure Container Registry.

Create another variable:

```text
ACR_LOGIN_SERVER
```

Set the value to the login server of your Azure Container Registry.

---

## 7. Run the CI Pipeline

Run the workflow manually from the **Actions** section of the GitHub repository.

Alteernatively, Make some changes in code and push the changes.

Monitor the workflow and confirm that all backend tests pass before the Docker image build and push jobs begin.

---

## 8. Verify Images in Azure Container Registry

After the CI pipeline completes successfully:

1. Open the Azure Portal.
2. Open your Azure Container Registry.
3. Select **Repositories**.
4. Verify that all application Docker images have been pushed successfully.

The CI pipeline is complete when all tests pass and all required Docker images are available in ACR.

---

## 9. Delete All Resources

Delete all Azure resources created for this example after completing the practical.
