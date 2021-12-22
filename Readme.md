# Hackaton for validation of crossreferences between STOP and IMOW

## Prerequisites:
- Make sure you have a working docker installation
- Have a dockerhub account available to get the MarkLogic images
- Log in to dockerhub

Adjust the .env environment file for use with Docker

Start up the container:
```shell
./start.sh

or

docker compose -p [someprojectname] up  -d 
```

`-d` option means run in detached mode.

After some time the container is up and running, check `http://localhost:8001` and see if you get a login screen.
Log in with user `admin` pwd `admin`

Copy the file gradle.properties to gradle-local.properties and adjust to the proper values for your environment.

Deploy the application to MarkLogic:
```shell
./gradlew mlDeploy
```

Load the ontologies:
```shell
./gradlew loadOntologies
```
Load the sample data:
```shell
./gradlew importData
```

Stop the container:
```shell
./stop.sh

or

docker compose -p [someprojectname] stop 
```

Remove the container:
```shell
docker compose -p [someprojectname] down 
```

Reload the tdes:
```shell
./gradlew mlReloadSchemas
```

Reload the modules:
```shell
./gradlew mlReloadModules
```

Load the workspace in QConsole:

- Goto localhost:8000/qconsole
- Click upper right corner next to Workspace
- Select `Import Workspace`
- Navigate to workspaces and select the workspace you want to import
- Workspace will be loaded and ready for use

