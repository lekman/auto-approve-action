# Setting up GitHub App for Auto-Approve Action

This guide explains how to set up a GitHub App for the Auto-Approve Action to work properly in CI/CD.

## Why a GitHub App?

The default `GITHUB_TOKEN` in GitHub Actions has limitations when it comes to approving pull requests. A GitHub App provides:
- Enhanced permissions for PR approval
- Better security with scoped access
- Ability to approve PRs on behalf of the app

## Step 1: Create a GitHub App

1. Go to your repository settings
2. Navigate to **Developer settings** > **GitHub Apps**
3. Click **New GitHub App**
4. Configure the app:
   - **Name**: `auto-approve-bot` (or your preferred name)
   - **Homepage URL**: Your repository URL
   - **Webhook**: Uncheck "Active"
   - **Permissions**:
     - **Repository permissions**:
       - Contents: Read
       - Pull requests: Write
       - Checks: Write (if you want to create checks)
     - **Organization permissions**: None needed
   - **Where can this GitHub App be installed?**: Only on this account

5. Click **Create GitHub App**

## Step 2: Generate Private Key

1. After creating the app, you'll be on the app's settings page
2. Scroll down to **Private keys**
3. Click **Generate a private key**
4. Save the downloaded `.pem` file securely

## Step 3: Install the App

1. On the app's settings page, click **Install App**
2. Choose your account (user or organization)
3. Select **Only select repositories** 
4. Choose the specific repository: `auto-approve-action` (or your repository name)
5. Click **Install**

**Important**: The app must be installed on the specific repository, not just at the user/organization level.

## Step 4: Configure Repository Settings

1. Note your **App ID** from the app's settings page (it's at the top)
2. Go to your repository's **Settings** > **Secrets and variables** > **Actions**
3. Add the following secrets:

### Repository Secrets
- Click on **Secrets** tab
- Add two secrets:

1. **APP_ID**
   - Click **New repository secret**
   - Name: `APP_ID`
   - Value: Your App ID (e.g., `123456`)

2. **APP_PRIVATE_KEY**
   - Click **New repository secret**
   - Name: `APP_PRIVATE_KEY`
   - Value: The entire contents of the `.pem` file you downloaded

## Step 5: Verify Setup

Push a commit or create a PR to trigger the CI workflow. The Setup job should now successfully generate a GitHub App token.

## Troubleshooting

### "Input required and not supplied: app-id"
- Make sure `APP_ID` is set as a repository secret
- Both `APP_ID` and `APP_PRIVATE_KEY` should be repository secrets
- Secrets are accessed with `secrets.APP_ID` and `secrets.APP_PRIVATE_KEY`

### "Not Found - get-a-user-installation-for-the-authenticated-app"
- This means the GitHub App is not installed on the repository
- Go to your GitHub App settings and click "Install App"
- Make sure to select the specific repository where you're running the action
- The app must be installed on the repository, not just created

### "Resource not accessible by integration"
- Check that your GitHub App has the correct permissions
- Ensure the app is installed on your repository
- Verify the private key is correctly formatted (include the entire PEM file)

### Token Permission Errors
- The workflow defines permissions at the job level
- Ensure your GitHub App has `pull_requests: write` permission
- Check that the app is installed with access to the specific repository