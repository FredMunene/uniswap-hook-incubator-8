A

Install the CRE CLI on your computer

You can use the 'curl' command below or download the latest CLI release on Github.

Terminal

`curl -sSL https://cre.chain.link/install.sh | bash`

B

Log in with the following CLI command

This will open your browser window and connect your CLI to your CRE account.

Terminal

cre login

A

Use the CLI to create a new project

Terminal

`cre init`

B

Name your project 'my-project'

A project is a folder that groups one or more workflows plus shared files.
C

Choose your workflow language

You can write workflows in either Golang or TypeScript.
D

Choose the 'Hello World' template

Get started with a simple "Hello World" workflow.
E

Name your workflow 'my-workflow'

This name identifies your workflow within the project. It’s used to create a dedicated folder that holds all your workflow code and configuration.
A

Change your directory to the project directory

Terminal

cd my-project

B

Start the simulation process

Run the workflow locally to view the workflow’s output.

Terminal

`cre workflow simulate my-workflow`

