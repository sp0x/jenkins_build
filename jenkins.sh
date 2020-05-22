#! /bin/bash -e

# If we were given a PORT environment variable, start as a simple daemon;
# otherwise, spawn a shell as well
if [ "$PORT" ]
then
	sudo exec dockerd --insecure-registry registry.netlyt.io -H 0.0.0.0:$PORT -H unix:///var/run/docker.sock \
		$DOCKER_DAEMON_ARGS &
else
	if [ "$LOG" == "file" ]
	then
		sudo dockerd --insecure-registry registry.netlyt.io $DOCKER_DAEMON_ARGS &>/tmp/docker.log &
	else
		sudo dockerd --insecure-registry registry.netlyt.io $DOCKER_DAEMON_ARGS &>/tmp/docker.log &
	fi
	(( timeout = 60 + SECONDS ))
	until docker info >/dev/null 2>&1
	do
		if (( SECONDS >= timeout )); then
			echo 'Timed out trying to connect to internal docker host.' >&2
			break
		fi
		sleep 1
	done
fi


: "${JENKINS_HOME:="/var/jenkins_home"}"
touch "${COPY_REFERENCE_FILE_LOG}" || { echo "Can not write to ${COPY_REFERENCE_FILE_LOG}. Wrong volume permissions?"; exit 1; }
echo "--- Copying files at $(date)" >> "$COPY_REFERENCE_FILE_LOG"
find /usr/share/jenkins/ref/ \( -type f -o -type l \) -exec bash -c '. /usr/local/bin/jenkins-support; for arg; do copy_reference_file "$arg"; done' _ {} +

# if `docker run` first argument start with `--` the user is passing jenkins launcher arguments
if [[ $# -lt 1 ]] || [[ "$1" == "--"* ]]; then

  # read JAVA_OPTS and JENKINS_OPTS into arrays to avoid need for eval (and associated vulnerabilities)
  java_opts_array=()
  while IFS= read -r -d '' item; do
    java_opts_array+=( "$item" )
  done < <([[ $JAVA_OPTS ]] && xargs printf '%s\0' <<<"$JAVA_OPTS")

  jenkins_opts_array=( )
  while IFS= read -r -d '' item; do
    jenkins_opts_array+=( "$item" )
  done < <([[ $JENKINS_OPTS ]] && xargs printf '%s\0' <<<"$JENKINS_OPTS")

  exec java -Duser.home="$JENKINS_HOME" "${java_opts_array[@]}" -jar /usr/share/jenkins/jenkins.war "${jenkins_opts_array[@]}" "$@"
fi
sudo chown jenkins:jenkins /var/run/docker.sock

# As argument is not jenkins, assume user want to run his own process, for example a `bash` shell to explore this image
exec "$@"
