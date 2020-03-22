#!/bin/bash -Eeu

readonly ROOT_DIR="$(cd "$(dirname "${0}")/.." && pwd)"
source "${ROOT_DIR}/sh/augmented_docker_compose.sh"
source "${ROOT_DIR}/sh/container_info.sh"
source "${ROOT_DIR}/sh/ip_address.sh"
readonly IP_ADDRESS=$(ip_address) # slow
export NO_PROMETHEUS=true

# - - - - - - - - - - - - - - - - - - -
containers_up()
{
  local -r server_port=${CYBER_DOJO_LANGUAGES_CHOOSER_PORT}
  local -r client_port=${CYBER_DOJO_LANGUAGES_CHOOSER_CLIENT_PORT}
  if [ "${1:-}" == 'api-demo' ]; then
    container_up_ready_and_clean ${server_port} languages-chooser
    container_up_ready_nginx
  elif [ "${1:-}" == 'server' ]; then
    container_up_ready_and_clean ${server_port} languages-chooser
  else
    container_up_ready_and_clean ${client_port} client
    container_up_ready_nginx
  fi
}

# - - - - - - - - - - - - - - - - - - -
container_up_ready_and_clean()
{
  local -r port="${1}"
  local -r service_name="${2}"
  container_up "${service_name}"
  # obtain container-up only once containers are up
  local -r container_name=$(service_container ${service_name})
  wait_briefly_until_ready "${port}" "${container_name}"
  exit_if_unclean "${container_name}"
}

# - - - - - - - - - - - - - - - - - - -
container_up()
{
  local -r service_name="${1}"
  printf '\n'
  augmented_docker_compose \
    up \
    --detach \
    --force-recreate \
      "${service_name}"
}

# - - - - - - - - - - - - - - - - - - - - - -
wait_briefly_until_ready()
{
  local -r port="${1}"
  local -r name="${2}"
  local -r max_tries=40
  printf "Waiting until ${name} is ready"
  for _ in $(seq ${max_tries}); do
    if curl_ready ${port}; then
      printf '.OK\n\n'
      docker logs ${name}
      return
    else
      printf .
      sleep 0.1
    fi
  done
  printf 'FAIL\n'
  printf "${name} not ready after ${max_tries} tries\n"
  if [ -f "$(ready_filename)" ]; then
    printf "$(ready_response)\n"
  else
    printf "$(ready_filename) does not exist?!\n"
  fi
  docker logs ${name}
  exit 42
}

# - - - - - - - - - - - - - - - - - - -
curl_ready()
{
  local -r port="${1}"
  local -r path=ready?
  local -r url="http://${IP_ADDRESS}:${port}/${path}"
  rm -f $(ready_filename)
  curl \
    --fail \
    --output $(ready_filename) \
    --request GET \
    --silent \
    "${url}"

  [ "$?" == '0' ] && [ "$(ready_response)" == '{"ready?":true}' ]
}

# - - - - - - - - - - - - - - - - - - -
ready_response() { cat "$(ready_filename)"; }
ready_filename() { printf /tmp/curl-languages-chooser-ready-output; }

# - - - - - - - - - - - - - - - - - - -
exit_if_unclean()
{
  local -r container_name="${1}"
  local log=$(docker logs "${container_name}" 2>&1)

  local -r mismatched_indent_warning="application(.*): warning: mismatched indentations at 'rescue' with 'begin'"
  log=$(strip_known_warning "${log}" "${mismatched_indent_warning}")

  printf "Checking ${container_name} started cleanly..."
  local -r line_count=$(echo -n "${log}" | grep -c '^')
  # 3 lines on Thin (Unicorn=6, Puma=6)
  #Thin web server (v1.7.2 codename Bachmanity)
  #Maximum connections set to 1024
  #Listening on 0.0.0.0:4536, CTRL+C to stop
  if [ "${line_count}" == '3' ]; then
    printf 'OK\n'
  else
    printf 'FAIL\n'
    print_docker_log "${container_name}" "${log}"
    exit 42
  fi
}

# - - - - - - - - - - - - - - - - - - -
strip_known_warning()
{
  local -r log="${1}"
  local -r known_warning="${2}"
  local stripped=$(printf "${log}" | grep --invert-match -E "${known_warning}")
  if [ "${log}" != "${stripped}" ]; then
    >&2 echo "SERVICE START-UP WARNING: ${known_warning}"
  else
    >&2 echo "DID _NOT_ FIND WARNING!!: ${known_warning}"
  fi
  echo "${stripped}"
}

# - - - - - - - - - - - - - - - - - - -
print_docker_log()
{
  local -r container_name="${1}"
  local -r log="${2}"
  printf "[docker logs ${container_name}]\n"
  printf '<docker_log>\n'
  printf "${log}\n"
  printf '</docker_log>\n'
}

# - - - - - - - - - - - - - - - - - - -
container_up_ready_nginx()
{
  container_up nginx
  printf "Waiting until nginx is ready"
  local -r max_tries=40
  for _ in $(seq ${max_tries}); do
    if curl_nginx; then
      printf '.OK\n'
      return
    else
      printf .
      sleep 0.1
    fi
  done
  printf 'FAIL\n'
  printf "nginx not ready after ${max_tries} tries\n"
  if [ -f "$(nginx_filename)" ]; then
    printf "$(nginx_response)\n"
  else
    printf "$(nginx_filename) does not exist?!\n"
  fi
  local -r container_name=$(service_container nginx)
  docker logs "${container_name}"
  exit 42
}

# - - - - - - - - - - - - - - - - - - -
curl_nginx()
{
  rm -f $(nginx_filename)
  local -r url="http://${IP_ADDRESS}:80/sha.txt"
  curl \
    --fail \
    --output $(nginx_filename) \
    --request GET \
    --silent \
    "${url}"

  [ "$?" == '0' ]
}

# - - - - - - - - - - - - - - - - - - -
nginx_response() { cat "$(nginx_filename)"; }
nginx_filename() { printf /tmp/curl-custom-chooser-nginx-output; }

#- - - - - - - - - - - - - - - - - - - - - - - - - - -
containers_up "$@"