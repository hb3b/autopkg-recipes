#!/bin/bash
#
# Copyright (c) 2011-2016 Carbon Black, Inc. All rights reserved.
#
# unattended install / upgrade of Carbon Black Defense Sensor for macOS
#
# required parameters: 
# - location of CbDefense PKG file
# - CompanyCode
#
# optional parameters:
# - Proxy Server
# - Proxy Server Creds
# - Last Attempt Proxy Server
# - Disable auto-update
# - Disable auto-update jitter
# - Pem File (cert. for the Backend Server)
# - File Upload Limit
# - Group Name
# - User name
# - Background Scan
# - Protection 
# - RateLimit
# - ConnectionLimit
# - QueueSize
# - LearningMode
# - POC
# - AllowDowngrade
# - Disable Live Response


#options
CBD_INSTALLER=""
COMPANY_CODE=""

#optional args
PROXY_SERVER=""
PROXY_CREDS=""
LAST_ATTEMPT_PROXY_SERVER=""
DISABLE_AUTOUPDATE=0
DISABLE_AUTOUPDATE_JITTER=0
BACKEND_SERVER_PEM=""
FILE_UPLOAD_LIMIT="" # empty for default
GROUP_NAME=""
USER_NAME=""
BSCAN=""
PROTECTION=""
POC=""
DISABLE_LIVE_RESPONSE=0

CB_DEFENSE_ALLOW_DOWNGRADE=0

# throttle args
unset RATE_LIMIT
unset CONNECTION_LIMIT
unset QUEUE_SIZE
unset LEARNING_MODE

#other vars
CBD_INSTALL_TMP="/tmp/cbdefense-install"
ME=`basename ${0}`
LOG="/tmp/${ME}.log"


function usage()
{
cat <<EOF

This tool installs or upgrades macOS Carbon Black Defense Sensor on this machine.

usage: ${0} options

OPTIONS:
   -h          Show this message
   -i          Path to CbDefense Install.pkg (required)
   -c          Company Code used to register the device (required)
   -p          Proxy server and port, e.g. 10.5.6.7:54443 (optional)
   -x          Proxy credentials, if required, e.g. username:password (optional), requires -p
   -l          Last Attempt proxy server and port, used if every other connectivity method fails, e.g. 10.5.6.7:54443 (optional)  
   -b          [deprecated] [optional] Backend Server address for OnPrem Install
   -m          Backend Server PEM file for OnPrem Install (optional)
   -u          Disable autoupdate (optional).  Auto-update is enabled by default.
   -t          File upload limit in MB (optional).  Default is no limit.
   -g          Group name (optional). The group to add the device to during registration.
   -o          User name / e-mail address override (optional). Used during registration and for identifying the device.
   -s          Background scan enable ("on") or disable ("off") (optional). Default is enabled. Cloud policy overrides this setting.
   -d          Protection after install disabled ("off") (sensor bypass mode), until reenabled later from Policy page.  This is optional.  Default is protection enabled after install.
   --downgrade Allow unattended downgrade. (optional) 
   --disable-upgrade-jitter Disable auto-upgrade jitter (optional)
   --disable-live-response Disable live response (optional)

Network Throttle Advanced Options (optional)
   --ratelimit
   --connectionlimit
   --queuesize
   --learningmode

Demo-mode only options (optional:
   --enable-poc POC fast startup (optional). Default is disabled.



EXAMPLES:
    ${0} -i /tmp/CbDefenseInstall.pkg -c 652797N7
    ${0} -i /tmp/CbDefenseInstall.pkg -c 652797N7 -p 10.0.3.3:123
    ${0} -i /tmp/CbDefenseInstall.pkg -c 652797N7 -p 10.0.3.3:123 -x myproxyuser:myproxypassword
    ${0} -i /tmp/CbDefenseInstall.pkg -c 652797N7 -u
    ${0} -i /tmp/CbDefenseInstall.pkg -c 652797N7 --downgrade
    ${0} -i /tmp/CbDefenseInstall.pkg -c 652797N7 -u -m /tmp/mycompany.pem
    ${0} -i /tmp/CbDefenseInstall.pkg -c 652797N7 -u -t 12 -s off -d off
    ${0} -i /tmp/CbDefenseInstall.pkg -c 652797N7 -g 'Administrators' -o 'adminuser2'
    ${0} -i /tmp/CbDefenseInstall.pkg -c 652797N7 --learningmode=30

EOF

}


### parse options

while getopts “ht:i:c:p:l:x:b:m:s:t:g:o:d:u-:” OPTION
do
     case $OPTION in
         h)
             usage
             exit 1
             ;;
         i)
             CBD_INSTALLER=${OPTARG}
             ;;
         c)
             COMPANY_CODE=${OPTARG}
             ;;
         p)
             PROXY_SERVER=${OPTARG}
             ;;
         x)
             PROXY_CREDS=${OPTARG}
             ;;
         l)
             LAST_ATTEMPT_PROXY_SERVER=${OPTARG}
             ;;
         b)
             #deprecated
             ;;
         m)
             BACKEND_SERVER_PEM=${OPTARG}	
             ;;
         s)
             BSCAN=${OPTARG}
             ;;
         t)
             FILE_UPLOAD_LIMIT=${OPTARG}
             ;;
         g)
             GROUP_NAME=${OPTARG}
             ;;
         o)
             USER_NAME=${OPTARG}
             ;;
         u)
             DISABLE_AUTOUPDATE=1
             ;;
         d)
             PROTECTION=${OPTARG}
             ;;

         -)
             case "${OPTARG}" in
		 downgrade)
                     val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
		     CB_DEFENSE_ALLOW_DOWNGRADE=1
                     ;;

                 downgrade=*)
		     CB_DEFENSE_ALLOW_DOWNGRADE=1
                     ;;

		 disable-upgrade-jitter)
                     val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
		     DISABLE_AUTOUPDATE_JITTER=1
                     ;;
		 
                 disable-upgrade-jitter=*)
		     DISABLE_AUTOUPDATE_JITTER=1
                     ;;

                 disable-live-response)
                     val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
                     DISABLE_LIVE_RESPONSE=1
                     ;;

                 disable-live-response=*)
                     DISABLE_LIVE_RESPONSE=1
                     ;;
                 
                 ratelimit)
                     val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
		     RATE_LIMIT=${val}
                     ;;
		 
                 ratelimit=*)
                     val=${OPTARG#*=}
                     opt=${OPTARG%=$val}
		     RATE_LIMIT=${val}
                     ;;

                 connectionlimit)
                     val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
		     CONNECTION_LIMIT=${val}
                     ;;

                 connectionlimit=*)
                     val=${OPTARG#*=}
                     opt=${OPTARG%=$val}
		     CONNECTION_LIMIT=${val}
                     ;;


                 queuesize)
                     val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
		     QUEUE_SIZE=${val}
                     ;;

                 queuesize=*)
                     val=${OPTARG#*=}
                     opt=${OPTARG%=$val}
		     QUEUE_SIZE=${val}
                     ;;


                 learningmode)
                     val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
		     LEARNING_MODE=${val}
                     ;;

                 learningmode=*)
                     val=${OPTARG#*=}
                     opt=${OPTARG%=$val}
		     LEARNING_MODE=${val}
                     ;;


                 enable-poc)
                     val="${!OPTIND}"; OPTIND=$(( $OPTIND + 1 ))
		     POC='on'
                     ;;

                 enable-poc=*)
                     val=${OPTARG#*=}
                     opt=${OPTARG%=$val}
		     POC=${val}
                     ;;
		 
                 *)
                     if [ "$OPTERR" = 1 ] && [ "${optspec:0:1}" != ":" ]; then
                         echo "ERROR: Unknown long option --${OPTARG}" >&2
			 usage
			 exit
                     fi
                     ;;
             esac;;
         ?)
	     echo "Invalid option: -${OPTARG}"
             usage
             exit
             ;;
     esac
done


function print_vals() {
    echo "CBD_INSTALLER=${CBD_INSTALLER}"
    echo "COMPANY_CODE=${COMPANY_CODE}"
    echo "PROXY_SERVER=${PROXY_SERVER}"
    echo "PROXY_CREDS=${PROXY_CREDS}"
    echo "LAST_ATTEMPT_PROXY_SERVER=${LAST_ATTEMPT_PROXY_SERVER}"
    echo "BACKEND_SERVER_PEM=${BACKEND_SERVER_PEM}"
    echo "DISABLE_AUTOUPDATE=${DISABLE_AUTOUPDATE}"
    echo "DISABLE_AUTOUPDATE_JITTER=${DISABLE_AUTOUPDATE_JITTER}"
    echo "FILE_UPLOAD_LIMIT=${FILE_UPLOAD_LIMIT}"
    echo "GROUP_NAME=${GROUP_NAME}"
    echo "USER_NAME=${USER_NAME}"
    echo "BSCAN=${BSCAN}"
    echo "PROTECTION=${PROTECTION}"
    echo "RATE_LIMIT=${RATE_LIMIT}"
    echo "CONNECTION_LIMIT=${CONNECTION_LIMIT}"
    echo "QUEUE_SIZE=${QUEUE_SIZE}"
    echo "LEARNING_MODE=${LEARNING_MODE}"
    echo "POC=${POC}"
    echo "DISABLE_LIVE_RESPONSE=${DISABLE_LIVE_RESPONSE}"
    echo "CB_DEFENSE_ALLOW_DOWNGRADE=${CB_DEFENSE_ALLOW_DOWNGRADE}"

}


function validate_options() {

    #print_vals

    ###validate options
    if [[ -z ${CBD_INSTALLER} ]] || [[ -z ${COMPANY_CODE} ]] ; then
        echo "ERROR: Path to CbDefense PKG file and company code are required parameters"
        usage
        exit 1
    fi
    if [[ ${#COMPANY_CODE} -lt 10 ]]; then
        echo "ERROR: Please enter the company code as specified in the backend"
        exit 1
    fi
    
    
    #proxy
    if [[ -n ${PROXY_CREDS} ]] ; then
	# check for required option
	if [[ -z ${PROXY_SERVER} ]] ; then
	    usage
	    exit 1
	fi

    fi

    # backend
    # if PEM, need server
    if [[ -n ${BACKEND_SERVER_PEM} ]] ; then
	    # check for required file
	    if [[ ! -f "${BACKEND_SERVER_PEM}" ]] ; then
	        echo "ERROR: Backend server PEM file not found: ${BACKEND_SERVER_PEM}"
	        exit 2
	    fi
    fi
}


function validate_run() {

    ###validate OS
    os=`uname`
    if [[ ${os} != 'Darwin' ]] ; then
	echo "ERROR: Unsupported OS, required macOS 10.6.8 or later"
	exit 3
    fi

    ###check the actual version 
    ###Note: installer will do that for us, but in the unattended mode, the message would be obscured
    version=`/usr/bin/sw_vers  | grep ProductVersion | cut -d':' -f2 | awk '{gsub(/^[ \t]+|[ \t]+$/,"");print}'`
    major=`echo ${version} | cut -d'.' -f1`
    minor=`echo ${version} | cut -d'.' -f2`
    patch=`echo ${version} | cut -d'.' -f3`
    
    if [[ -n ${version} ]] ; then
	echo "Detected macOS version: ${major}.${minor}.${patch}"

	if [[ ${major} -lt 10 ]] ||   
	    ( [[ ${major} -eq 10 ]] && [[ ${minor} -lt 8 ]] ) ; then
	    echo "ERROR: Unsupported OS, required macOS 10.8 or later"
	    exit 3
	    
	else
	    # check max supported version
	    if [[ ${major} -eq 10 ]] && [[ ${minor} -gt 13 ]] ; then
		echo "WARNING: Unsupported OS, required max. macOS 10.13"
	    else
		echo "Version ${major}.${minor}.${patch} OK"
	    fi
	    
	fi
    fi

    ###validate install framework
    if [[ ! -x /usr/sbin/installer ]] ; then
	echo "ERROR: Installer framework not found"
	exit 4
    fi

    ###validate privileges
    user=`whoami`
    if [[ ${user} != "root" ]] ; then
	echo "ERROR: root privileges are required to install CbDefense Sensor."
	#setup
	exit 1
    fi
    

    ###validate pkg
    if [[ ! -f "${CBD_INSTALLER}" ]] ; then
	echo "ERROR: CbDefense Installer ${CBD_INSTALLER} file not found"
	exit 2
    fi
    
    ###validate pkg is CbDefense on OSX > 10.6 (need pkgutil support)
    if [[ ${minor} -gt 6 ]] ; then
	if [[ -x /usr/sbin/pkgutil ]] ; then
	    err=`/usr/sbin/pkgutil --check-signature "${CBD_INSTALLER}" | grep '(JA7945SK43)'`
	    er=$?
	    if [[ ${er} -ne 0 ]] ; then
		err=`/usr/sbin/pkgutil --check-signature "${CBD_INSTALLER}" | grep '(7AGZNQ2S2T)'`
		er=$?
		if [[ ${er} -ne 0 ]] ; then
		    echo "ERROR: CbDefense Installer cannot be verified: $err:$er"
		    exit 3
		fi		
	    fi	    
	fi
    fi
    

    echo "Validation OK"

}



function setup() {

    ###setup temp
    rm -rf ${CBD_INSTALL_TMP}
    mkdir -p ${CBD_INSTALL_TMP}
    
    ###setup ini

    echo "[customer]" > ${CBD_INSTALL_TMP}/cfg.ini

    echo "Code=${COMPANY_CODE}" >> ${CBD_INSTALL_TMP}/cfg.ini
    
    # Proxy
    if [[ -n ${PROXY_SERVER} ]] ; then
	echo "Using Proxy Server: ${PROXY_SERVER}" 
	echo "ProxyServer=${PROXY_SERVER}" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi
    
    if [[ -n ${PROXY_CREDS} ]] ; then
	echo "Using Proxy Creds" 
	echo "ProxyServerCredentials=${PROXY_CREDS}" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

    # Last Attempt Proxy
    if [[ -n ${LAST_ATTEMPT_PROXY_SERVER} ]] ; then
	echo "Using Last Attempt Proxy Server: ${LAST_ATTEMPT_PROXY_SERVER}" 
	echo "LastAttemptProxyServer=${LAST_ATTEMPT_PROXY_SERVER}" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi


    # onPrem server
    if [[ -n ${BACKEND_SERVER_PEM} ]] ; then
        echo "Using OnPrem backend server PEM: ${BACKEND_SERVER_PEM}"
        cp -f "${BACKEND_SERVER_PEM}" "${CBD_INSTALL_TMP}/customer.pem"
        if [[ ! -f "${CBD_INSTALL_TMP}/customer.pem" ]] ; then
            echo "ERROR: could not copy customer.pem"
            exit 5
        fi
        echo "PemFile=customer.pem" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

    
    # no AutoUpdate
    if [[ ${DISABLE_AUTOUPDATE} -eq 1 ]] ; then
	echo "Auto update is disabled"
	echo "AutoUpdate=false" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

    # no AutoUpdate jitter
    if [[ ${DISABLE_AUTOUPDATE_JITTER} -eq 1 ]] ; then
	echo "Auto update jitter is disabled"
	echo "AutoUpdateJitter=false" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi


    # protection
    if [[ -n ${PROTECTION} ]] ; then
	if [[ ${PROTECTION} == 'off' ]] || [[ ${PROTECTION} == 'false' ]] ; then
	    echo "Disabling protection after install. Group policy can override this."
	    echo "InstallBypass=true" >> ${CBD_INSTALL_TMP}/cfg.ini
	else
	    echo "Protection: using the default (enabled). Group policy can override this."
	fi
    else
	echo "Protection: using the default (enabled). Group policy can override this."
    fi

    # upload limit
    if [[ -n ${FILE_UPLOAD_LIMIT} ]] ; then

	if [[ ${FILE_UPLOAD_LIMIT} -gt 0 ]] ; then
            echo "Using file upload limit: ${FILE_UPLOAD_LIMIT} "
            echo "FileUploadLimit=${FILE_UPLOAD_LIMIT}" >> ${CBD_INSTALL_TMP}/cfg.ini
	elif [[ ${FILE_UPLOAD_LIMIT} -eq 0 ]] ; then
	    echo "No file upload limit"
            echo "FileUploadLimit=0" >> ${CBD_INSTALL_TMP}/cfg.ini
	fi
    else 
	echo "No file upload limit specified, using default."
    fi

    # group name
    if [[ -n ${GROUP_NAME} ]] ; then
        echo "Using register group name: ${GROUP_NAME}"
        echo "GroupName=${GROUP_NAME}" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

    # user name
    if [[ -n ${USER_NAME} ]] ; then
        echo "Using register user name: ${USER_NAME}"
        echo "EmailAddress=${USER_NAME}" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

    # background scan
    if [[ -n ${BSCAN} ]] ; then
	BSCAN_VAL='false'
	if [[ ${BSCAN} == 'on' ]] || [[ ${BSCAN} == 'true' ]] ; then
	    echo "Enabling background scan"
	    echo "BackgroundScan=true" >> ${CBD_INSTALL_TMP}/cfg.ini
	elif [[ ${BSCAN} == 'off' ]] || [[ ${BSCAN} == 'false' ]] ; then
	    echo "Disabling background scan"
	    echo "BackgroundScan=false" >> ${CBD_INSTALL_TMP}/cfg.ini
	else
	    echo "Invalid background scan setting: ${BSCAN}, using the default (off)"
	fi
    else
	echo "Background scan, using the default (enabled). Group policy can override this."
    fi


    # rate-limit
    if [[ -n ${RATE_LIMIT} ]] ; then
        echo "Using RateLimit: ${RATE_LIMIT}"
        echo "RateLimit=${RATE_LIMIT}" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

    # connection-limit
    if [[ -n ${CONNECTION_LIMIT} ]] ; then
        echo "Using ConnectionLimit: ${CONNECTION_LIMIT}"
        echo "ConnectionLimit=${CONNECTION_LIMIT}" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

    # queue-size
    if [[ -n ${QUEUE_SIZE} ]] ; then
        echo "Using QueueSize: ${QUEUE_SIZE}"
        echo "QueueSize=${QUEUE_SIZE}" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

    # learning-mode
    if [[ -n ${LEARNING_MODE} ]] ; then
        echo "Using LearningMode: ${LEARNING_MODE}"
        echo "LearningMode=${LEARNING_MODE}" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

    # POC
    if [[ -n ${POC} ]] ; then
	if [[ ${POC} == 'on' ]] || [[ ${POC} == 'true' ]] ; then
	    echo "Enabling POC"
	    echo "POC=1" >> ${CBD_INSTALL_TMP}/cfg.ini
	else
	    echo "POC: using the default (disabled)"
	fi
    fi

    # downgrade
    touch ${CBD_INSTALL_TMP}/params
    if [[ ${CB_DEFENSE_ALLOW_DOWNGRADE} -eq 1 ]] ; then
        echo "Downgrade allowed"
        echo "CB_DEFENSE_ALLOW_DOWNGRADE=1" >> ${CBD_INSTALL_TMP}/params
    else
	echo "Downgrade not allowed"
    fi

    # live response
    if [[ ${DISABLE_LIVE_RESPONSE} -eq 1 ]] ; then
	echo "Live Response is disabled"
	echo "CbLRKill=true" >> ${CBD_INSTALL_TMP}/cfg.ini
    fi

}



function install() {

    ###run install / upgrade
    # run the installer in silent mode
    # it will detect fresh install case vs silent upgrade
    
    run_install_log=$(/usr/sbin/installer -verbose -pkg "${CBD_INSTALLER}" -target / 2>&1)
    err=${?}
    echo ${run_install_log} >> ${LOG}

    if [[ ${err} -eq 0 ]] ; then
	echo "Carbon Black Defense installed/upgraded successfully"
	exit 0
    else
	echo "Carbon Black Defense installation/upgrade error: ${err}"
	echo ${run_install_log}
	exit 10
    fi


}


function main() {

    validate_options
    validate_run
    setup
    install
}


# run everything
main
