#!/usr/bin/env bash
set -Eeuo pipefail

buildDir=build/php
versions=( $buildDir/* )
versions=( "${versions[@]%/}" )

generated_warning() {
	cat <<-EOH
		#
		# NOTE: THIS DOCKERFILE IS GENERATED VIA "update.sh"
		#
		# PLEASE DO NOT EDIT IT DIRECTLY.
		#
	EOH
}

for version in "${versions[@]}"; do

    version=$(basename ${version})
    rcVersion="${version%-rc}"

    echo $version
    #continue

    # "7", "5", etc
    majorVersion="${rcVersion%%.*}"
    # "2", "1", "6", etc
    minorVersion="${rcVersion#$majorVersion.}"
    minorVersion="${minorVersion%%.*}"

    dockerfiles=()

    baseDockerfile=Dockerfile.template

    for variant in cli fpm; do
        [ -d "$buildDir/$version/$variant" ] || continue

        for distribution in buster bullseye; do
          [ -d "$buildDir/$version/$variant/$distribution" ] || continue

          for debug in debug no-debug; do
              { generated_warning; cat "$baseDockerfile"; } > "$buildDir/$version/$variant/$distribution/$debug/Dockerfile"

              envBlock="$variant"
              variantEnvVar="${version}-${variant}-env-Dockerfile-block-1"

              if [ -f $variantEnvVar ]; then
                envBlock="${version}-${variant}"
              fi

              echo "Generating $buildDir/$version/$variant/$distribution/$debug/Dockerfile from $baseDockerfile + $envBlock-env-Dockerfile-block-*"
              gawk -i inplace -v env="$envBlock" '
                  $1 == "##</env>##" { ia = 0 }
                  !ia { print }
                  $1 == "##<env>##" { ia = 1; ab++; ac = 0; if (system("test -f " env "-env-Dockerfile-block-" ab) != 0) { ia = 0 } }
                  ia { ac++ }
                  ia && ac == 1 { system("cat " env "-env-Dockerfile-block-" ab) }
              ' "$buildDir/$version/$variant/$distribution/$debug/Dockerfile"

              echo "Generating $buildDir/$version/$variant/$distribution/$debug/Dockerfile from $baseDockerfile + $variant-Dockerfile-block-*"
              gawk -i inplace -v variant="$variant" '
                  $1 == "##</autogenerated>##" { ia = 0 }
                  !ia { print }
                  $1 == "##<autogenerated>##" { ia = 1; ab++; ac = 0; if (system("test -f " variant "-Dockerfile-block-" ab) != 0) { ia = 0 } }
                  ia { ac++ }
                  ia && ac == 1 { system("cat " variant "-Dockerfile-block-" ab) }
              ' "$buildDir/$version/$variant/$distribution/$debug/Dockerfile"

              echo "Generating $buildDir/$version/$variant/$distribution/$debug/Dockerfile from $baseDockerfile + $version-Dockerfile-block-*"
              gawk -i inplace -v variant="$version" '
                  $1 == "##</version>##" { ia = 0 }
                  !ia { print }
                  $1 == "##<version>##" { ia = 1; ab++; ac = 0; if (system("test -f " variant "-Dockerfile-block-" ab) != 0) { ia = 0 } }
                  ia { ac++ }
                  ia && ac == 1 { system("cat " variant "-Dockerfile-block-" ab) }
              ' "$buildDir/$version/$variant/$distribution/$debug/Dockerfile"

              debugBlock="$debug"

              if [ debug = 'debug' ]; then
                versionDebugFile="${debug}-${version}-Dockerfile-block-1"

                if [ -f $versionDebugFile ]; then
                  debugBlock="${debug}-${version}"
                else
                  debugBlock="$debug"
                fi
              fi

              echo "Generating $buildDir/$version/$variant/$distribution/$debug/Dockerfile from $baseDockerfile + $debugBlock-Dockerfile-block-*"
              gawk -i inplace -v variant="$debugBlock" '
                  $1 == "##</debug>##" { ia = 0 }
                  !ia { print }
                  $1 == "##<debug>##" { ia = 1; ab++; ac = 0; if (system("test -f " variant "-Dockerfile-block-" ab) != 0) { ia = 0 } }
                  ia { ac++ }
                  ia && ac == 1 { system("cat " variant "-Dockerfile-block-" ab) }
              ' "$buildDir/$version/$variant/$distribution/$debug/Dockerfile"

              echo "Generating $buildDir/$version/$variant/$distribution/$debug/Dockerfile from $baseDockerfile + $distribution-Dockerfile-block-*"
              gawk -i inplace -v distribution="$distribution" '
                  $1 == "##</distribution>##" { ia = 0 }
                  !ia { print }
                  $1 == "##<distribution>##" { ia = 1; ab++; ac = 0; if (system("test -f " variant "-Dockerfile-block-" ab) != 0) { ia = 0 } }
                  ia { ac++ }
                  ia && ac == 1 { system("cat " variant "-Dockerfile-block-" ab) }
              ' "$buildDir/$version/$variant/$distribution/$debug/Dockerfile"

              if [ -d "files/$variant/" ]; then
                echo "Copy from files/$variant to $buildDir/$version/$variant/$distribution/$debug"
                cp -rf "files/$variant/." $buildDir/$version/$variant/$distribution/$debug/
              fi

              if [ -d "files/$debug/" ]; then
                echo "Copy from files/$debug to $buildDir/$version/$variant/$distribution/$debug"
                cp -rf "files/$debug/." $buildDir/$version/$variant/$distribution/$debug/
              fi

              if [ -d "files/$distribution/$debug/" ]; then
                echo "Copy from files/$distribution/$debug to $buildDir/$version/$variant/$distribution/$debug"
                cp -rf "files/$distribution/$debug/." $buildDir/$version/$variant/$distribution/$debug/
              fi

              if [ -d "files/$version/$debug/" ]; then
                echo "Copy from files/$version/$debug to $buildDir/$version/$variant/$distribution/$debug"
                cp -rf "files/$version/$debug/." $buildDir/$version/$variant/$distribution/$debug/
              fi

              if [ -d "files/$version/$variant/" ]; then
                echo "Copy from files/$version/$variant to $buildDir/$version/$variant/$distribution/$debug"
                cp -rf "files/$version/$variant/." $buildDir/$version/$variant/$distribution/$debug/
              fi

              # remove any _extra_ blank lines created by the deletions above
              awk '
                  NF > 0 { blank = 0 }
                  NF == 0 { ++blank }
                  blank < 2 { print }
              ' "$buildDir/$version/$variant/$distribution/$debug/Dockerfile" > "$buildDir/$version/$variant/$distribution/$debug/Dockerfile.new"
              mv "$buildDir/$version/$variant/$distribution/$debug/Dockerfile.new" "$buildDir/$version/$variant/$distribution/$debug/Dockerfile"

              sed -ri \
                  -e 's!%%PHP_TAG%%!'"$version"'!' \
                  -e 's!%%IMAGE_VARIANT%%!'"$variant"'!' \
                  -e 's!%%DISTRIBUTION%%!'"$distribution"'!' \
                  "$buildDir/$version/$variant/$distribution/$debug/Dockerfile"
              dockerfiles+=( "$buildDir/$version/$variant/$distribution/$debug/Dockerfile" )
          done
        done
    done
done
