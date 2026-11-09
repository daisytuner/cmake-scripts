# cmake/Version.cmake

include_guard(GLOBAL)

# parse_version(BASE <MAJOR.MINOR> RELEASE_ENV <env-var> GIT_DIR <dir>
#               OUT_VERSION <var> OUT_VERSION_FULL <var>)
#
# Derives a project's version from its committed MAJOR.MINOR. The patch number is only known to release
# builds, which pass the full MAJOR.MINOR.PATCH in the environment variable RELEASE_ENV. Builds without it
# are dev builds, identified by the short hash of the commit checked out in GIT_DIR. Dev versions have no
# patch number, so they cannot be mistaken for a release.
#   OUT_VERSION       numeric, as project(VERSION) and library sonames require: MAJOR.MINOR.PATCH for
#                     releases, MAJOR.MINOR for dev builds (PROJECT_VERSION_PATCH is then empty)
#   OUT_VERSION_FULL  the release version, or MAJOR.MINOR+g<hash> for dev builds (e.g. 0.8+gabc1234); use
#                     it for package versions, install prefixes and version strings shown to users
# Callers that read BASE from a file should add it to CMAKE_CONFIGURE_DEPENDS. The commit hash is
# captured at configure time.
function(parse_version)
    cmake_parse_arguments(PARSE_ARGV 0 ARG "" "BASE;RELEASE_ENV;GIT_DIR;OUT_VERSION;OUT_VERSION_FULL" "")
    if(ARG_UNPARSED_ARGUMENTS)
        message(FATAL_ERROR "parse_version: unexpected arguments '${ARG_UNPARSED_ARGUMENTS}'")
    endif()
    foreach(arg IN ITEMS RELEASE_ENV GIT_DIR OUT_VERSION OUT_VERSION_FULL)
        if("${ARG_${arg}}" STREQUAL "")
            message(FATAL_ERROR "parse_version: ${arg} is required")
        endif()
    endforeach()

    if(NOT ARG_BASE MATCHES "^[0-9]+\\.[0-9]+$")
        message(FATAL_ERROR "parse_version: BASE must be MAJOR.MINOR (e.g. 0.8), got '${ARG_BASE}'")
    endif()

    set(release "$ENV{${ARG_RELEASE_ENV}}")
    if(NOT release STREQUAL "")
        # Release build: the full version was allocated for this BASE by the release workflow.
        if(NOT release MATCHES "^([0-9]+\\.[0-9]+)\\.[0-9]+$")
            message(FATAL_ERROR "${ARG_RELEASE_ENV} must be MAJOR.MINOR.PATCH (e.g. 0.8.4), got '${release}'")
        endif()
        # Catches a stale value left in a shell, which would otherwise mislabel the build.
        if(NOT CMAKE_MATCH_1 STREQUAL ARG_BASE)
            message(FATAL_ERROR "${ARG_RELEASE_ENV} '${release}' does not belong to version base '${ARG_BASE}'")
        endif()
        set(version "${release}")
        set(version_full "${release}")
    else()
        set(version "${ARG_BASE}")
        execute_process(
            COMMAND git rev-parse --short HEAD
            WORKING_DIRECTORY "${ARG_GIT_DIR}"
            OUTPUT_VARIABLE git_hash
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_QUIET
            RESULT_VARIABLE git_result
        )
        # No git, or git refusing the checkout (e.g. a container with a different owner).
        if(NOT git_result EQUAL 0 OR git_hash STREQUAL "")
            set(git_hash "unknown")
        endif()
        # "+" rather than "-": it is valid in both Debian and RPM versions, while RPM rejects "-".
        # Both also sort MAJOR.MINOR+g<hash> below the first release MAJOR.MINOR.0.
        set(version_full "${ARG_BASE}+g${git_hash}")
    endif()

    set(${ARG_OUT_VERSION} "${version}" PARENT_SCOPE)
    set(${ARG_OUT_VERSION_FULL} "${version_full}" PARENT_SCOPE)
endfunction()
