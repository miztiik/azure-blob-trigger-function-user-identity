# set -x
set -e

# Set Global Variables
MAIN_BICEP_TEMPL_NAME="main.bicep"
LOCATION=$(jq -r '.parameters.deploymentParams.value.location' params.json)
SUB_DEPLOYMENT_PREFIX=$(jq -r '.parameters.deploymentParams.value.sub_deploymnet_prefix' params.json)
ENTERPRISE_NAME=$(jq -r '.parameters.deploymentParams.value.enterprise_name' params.json)
ENTERPRISE_NAME_SUFFIX=$(jq -r '.parameters.deploymentParams.value.enterprise_name_suffix' params.json)
GLOBAL_UNIQUENESS=$(jq -r '.parameters.deploymentParams.value.global_uniqueness' params.json)

RG_NAME="${ENTERPRISE_NAME}_${ENTERPRISE_NAME_SUFFIX}_${GLOBAL_UNIQUENESS}"


# # Generate and SSH key pair to pass the public key as parameter
# ssh-keygen -m PEM -t rsa -b 4096 -C '' -f ./miztiik.pem

# pubkeydata=$(cat miztiik.pem.pub)

DEPLOYMENT_OUTPUT_1=""

# Function Deploy all resources
function deploy_everything()
{
az bicep build --file $1

# Initiate Deployments
echo -e "\033[33m Initiating Subscription Deployment \033[0m" # Yellow
echo -e "\033[32m  - ${SUB_DEPLOYMENT_PREFIX}"-"${GLOBAL_UNIQUENESS} at ${LOCATION} \033[0m" # Green

DEPLOYMENT_OUTPUT_1=$(az deployment sub create \
                    --name ${SUB_DEPLOYMENT_PREFIX}"-"${GLOBAL_UNIQUENESS}"-Deployment" \
                    --location ${LOCATION} \
                    --parameters @params.json \
                    --template-file $1 \
                    # --confirm-with-what-if
                    )


echo $DEPLOYMENT_OUTPUT_1
saName=`echo $DEPLOYMENT_OUTPUT_1 | jq -r '.properties.outputs["saName"].value'`
echo "saName: $saName"


# Deploy function code
# deploy_func_code

}


# Publish the function App
function deploy_func_code(){
FUNC_APP_NAME_PART_1=$(jq -r '.parameters.funcParams.value.funcAppPrefix' params.json)
FUNC_APP_NAME_PART_2="-fnApp-"
GLOBAL_UNIQUENESS=$(jq -r '.parameters.deploymentParams.value.global_uniqueness' params.json)
FUNC_APP_NAME=${FUNC_APP_NAME_PART_1}${FUNC_APP_NAME_PART_2}${GLOBAL_UNIQUENESS}
FUNC_CODE_LOCATION="./app/function_code/store-backend-ops/"

cd ${FUNC_CODE_LOCATION}

# Initiate Deployments
echo -e "\033[33m Initiating Python Function Deployment \033[0m" # Yellow
echo -e "\033[32m Deploying code at ${FUNC_CODE_LOCATION} to ${FUNC_APP_NAME} \033[0m" # Green

func azure functionapp publish ${FUNC_APP_NAME} --nozip
}





deploy_everything $MAIN_BICEP_TEMPL_NAME
deploy_func_code


