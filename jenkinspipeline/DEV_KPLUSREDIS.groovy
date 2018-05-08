node('master'){
    def MailList="somchai.kasantikul@gmail.com"
    def modulenamedocker = "redis-cluster"
    def GITREPO = "https://github.com/manoframa9/jkpipeline-rediscluster.git"
    def GITCREDENTIAL = "manoframa9"
    def LOCALJFROGPASSWORD = "manoframa9"
    def OCPADM = "ocpadm"
    stage ('PULL CODE') {
        try{
            // GITLAB_TAG is a parameter of the jenkins pipeline
			checkout([$class: 'GitSCM', branches: [[name: "${GITLAB_TAG}"]], doGenerateSubmoduleConfigurations: false, extensions: [], submoduleCfg: [], userRemoteConfigs: [[credentialsId: "${GITCREDENTIAL}", url: "${GITREPO}"]]])
			currentBuild.displayName = "#${env.BUILD_NUMBER}_${GITLAB_TAG}"
            }catch(err){
                currentBuild.result = 'FAILURE'
                String emailheader = "Dear developers,\r\n\r\nPlease check details of Redis-Cluster in Development environment.\r\n\r\n"
                println "${emailheader}"
                String emailbody = "Please see result in attachment."
                emailext  attachLog: true,  compressLog: true, body: "${emailheader}${emailbody}", subject: "[Jenkins Dev env.] <!! Pull code fail !!> Redis-Cluster ", to: "${MailList}"
                error("Catch and error -- Stop build")
            }
    }

	stage ('Build image Redis-Cluster') {
        try{
		    withEnv(["buildnosh=${env.BUILD_NUMBER}"]) {
            // Build docker file with adding a time-stamp data into image.
		    sh '''
			docker build --build-arg BUILD_TIME="Build number $buildnosh : Build on $(date)" . -t manoframa9/jkpipeline-rediscluster:${GITLAB_TAG}
			'''
			}
        }catch(err){
                currentBuild.result = 'FAILURE'
                String emailheader = "Dear developers,\r\n\r\nPlease check details of Redis-Cluster in Development environment.\r\n\r\n"
                println "${emailheader}"
                String emailbody = "Please see result in attachment."
                emailext  attachLog: true,  compressLog: true, body: "${emailheader}${emailbody}", subject: "[Jenkins Dev env.] <!! Build image fail !!> Redis-Cluster ", to: "${MailList}"
                error("Catch and error -- Stop build")
        }
	}
		
	stage ('Push image to local docker registry') {
        try{
            // Need to config a secret text for the password in Jenkins
		withCredentials([string(credentialsId: "${LOCALJFROGPASSWORD}", variable: 'ARTIFACT_PWD')]) {
       	sh '''
       	    docker login -u manoframa9 -p ${ARTIFACT_PWD} hub.docker.io
       	    docker push manoframa9/jkpipeline-rediscluster:${GITLAB_TAG}
       	 
       	'''
		}
        }catch(err){
                currentBuild.result = 'FAILURE'
                String emailheader = "Dear developers,\r\n\r\nPlease check details of Redis-Cluster in Development environment.\r\n\r\n"
                println "${emailheader}"
                String emailbody = "Please see result in attachment."
                emailext  attachLog: true,  compressLog: true, body: "${emailheader}${emailbody}", subject: "[Jenkins Dev env.] <!! Push image to artifactory fail !!> Redis-Cluster ", to: "${MailList}"
                error("Catch and error -- Stop build")
        }
    }
	stage ('Deploy image to OpenShift') {
        try{
            // Need to create a secret text for the password of ocpadm
	    withCredentials([string(credentialsId: "${OCPADM}", variable: 'OCPADM_PWD')]) {
        withEnv(["modulenamedockersh=${modulenamedocker}"]) {
		sh '''
            AppVersion="noVersion" ## apply only in dev environment
	        OCPCONFIG_PATH="ocpconfig"
            DEPLOYMENTSH_PATH="jenkinspipeline"
            oc login -u ocpadm -p ${OCPADM_PWD} openshift-test.myorg.com
            oc project DEV

            oc replace -f ${OCPCONFIG_PATH}/DEV-${modulenamedockersh}-dev-cm-jenkins.yaml --force --cascade=true
           
            
            cd ${OCPCONFIG_PATH}
            NUMB_NODE="$(( $((${NUMB_REPLICAS} + 1)) * ${NUMB_MASTER} ))"
            PID_LIST=""
            nodeinststr="" #formated number by pading 0 on left hand side
            nodeinst="0"   #number of node-id
            zoneid="0"     #zone number of a pod
            for numbreplicas in $(seq 1 $((${NUMB_REPLICAS} + 1)) )
            do
                for numbmaster in $(seq 1 ${NUMB_MASTER})
                do
                    let "nodeinst+=1"
                    ### calculation to shift right one zone on each level. master shift 0; slave level 1 shift 1, slave level 2 shift 2
                    zoneid=$(( (${nodeinst}+${numbreplicas}-1)%3 ))
                    echo "zoneid = ${zoneid}"
                    printf -v nodeinststr "%02d" $nodeinst ##formated nodeinst value
                    if [ "$nodeinst" != "$NUMB_NODE" ] 
                    then
                        echo " >>>>>>>>>> Start deployment ${modulenamedockersh}-node${nodeinststr}"
                        echo "../${DEPLOYMENTSH_PATH}/deploynode.sh ${GITLAB_TAG} ${NUMB_NODE} ${nodeinststr} blue ${NUMB_REPLICAS} DEV zone${zoneid}"
                        timeout 5m ../${DEPLOYMENTSH_PATH}/deploynode.sh ${GITLAB_TAG} ${NUMB_NODE} ${nodeinststr} blue ${NUMB_REPLICAS} DEV zone${zoneid} & pid=$! && PID_LIST+=" $pid" && echo "Spawned PIDs => $PID_LIST" && echo $PID_LIST>PID_LIST.txt
                    else
                        ## Wait until all early node are deploy success.
                        wait $PID_LIST
                        echo ">>>>>>>>>>>>>>>>>>>>>> All previous node created. Create the last node and init cluster." 
                        echo "../${DEPLOYMENTSH_PATH}/deploynode.sh  ${GITLAB_TAG} ${NUMB_NODE} ${nodeinststr} dev ${NUMB_REPLICAS} DEV zone${zoneid}"
                        timeout 5m ../${DEPLOYMENTSH_PATH}/deploynode.sh  ${GITLAB_TAG} ${NUMB_NODE} ${nodeinststr} dev ${NUMB_REPLICAS} DEV zone${zoneid}
                        PID_LIST=""
                    fi
                done
                wait $PID_LIST
                PID_LIST=""
            done
            ### change deployer to OCP. This will make redis pods start after this will start with "redis-trib.rb add-node --slave" command
            oc replace -f DEV-${modulenamedockersh}-dev-cm-ocp.yaml --force
            '''
        }
        }
        }catch(err){
                currentBuild.result = 'FAILURE'
                String emailheader = "Dear developers,\r\n\r\nPlease check details of Redis-Cluster in Development environment.\r\n\r\n"
                println "${emailheader}"
                String emailbody = "Please see result in attachment."
                emailext  attachLog: true,  compressLog: true, body: "${emailheader}${emailbody}", subject: "[Jenkins Dev env.] <!! Deploy to OCP fail !!> Redis-Cluster ", to: "${MailList}"
                error("Catch and error -- Stop build")
        }
	}
    stage ('Send e-mail notify success') {
        currentBuild.result = 'SUCCESS'
        String emailheader = "Dear developers,\r\n\r\nPlease check details of Redis-Cluster in Development environment.\r\n\r\n"
        println "${emailheader}"
        String emailbody = "Please see result in attachment."
        emailext  attachLog: true,  compressLog: true, body: "${emailheader}${emailbody}", subject: "[Jenkins DEV env.] < Success deployment > Redis-Custer ", to: "${MailList}"
    }
}