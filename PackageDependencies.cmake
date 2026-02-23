# cmake/PackageDependencies.cmake

include_guard(GLOBAL)

# Properties for targets to list abstract dependencies
define_property(TARGET PROPERTY PACKAGE_RUNTIME_DEPS
    BRIEF_DOCS "List of abstract runtime library dependencies"
    FULL_DOCS "Abstract names of libraries this target depends on (e.g. 'libzip', 'boost-program-options')"
)

define_property(TARGET PROPERTY PACKAGE_TOOL_DEPS
    BRIEF_DOCS "List of abstract tool dependencies"
    FULL_DOCS "Abstract names of command line tools this target depends on (e.g. 'git', 'python3')"
)

# Helper to add dependencies to a target
function(target_package_deps target)
    cmake_parse_arguments(PARSE_ARGV 1 ARG "" "" "RUNTIME;TOOLS")
    
    if(NOT TARGET "${target}")
        message(FATAL_ERROR "target_package_deps called on non-target: ${target}")
    endif()

    if(ARG_RUNTIME)
        set_property(TARGET "${target}" APPEND PROPERTY PACKAGE_RUNTIME_DEPS ${ARG_RUNTIME})
    endif()
    
    if(ARG_TOOLS)
        set_property(TARGET "${target}" APPEND PROPERTY PACKAGE_TOOL_DEPS ${ARG_TOOLS})
    endif()
endfunction()

# ----------------- Detection Logic -----------------

if(NOT DEFINED PACKAGE_DISTRO_ID OR NOT DEFINED PACKAGE_DISTRO_VERSION)
    find_program(LSB_RELEASE_CMD lsb_release)
    if(LSB_RELEASE_CMD)
        execute_process(COMMAND ${LSB_RELEASE_CMD} -is OUTPUT_VARIABLE _distro_id OUTPUT_STRIP_TRAILING_WHITESPACE)
        execute_process(COMMAND ${LSB_RELEASE_CMD} -rs OUTPUT_VARIABLE _distro_ver OUTPUT_STRIP_TRAILING_WHITESPACE)
        string(TOLOWER "${_distro_id}" PACKAGE_DISTRO_ID)
        string(TOLOWER "${_distro_ver}" PACKAGE_DISTRO_VERSION)
    else()
        if(EXISTS "/etc/os-release")
            file(STRINGS "/etc/os-release" OS_RELEASE_LINES)
            foreach(line IN LISTS OS_RELEASE_LINES)
                if(line MATCHES "^ID=[\"]?([a-zA-Z0-9_.-]+)[\"]?")
                    set(PACKAGE_DISTRO_ID ${CMAKE_MATCH_1})
                endif()
                if(line MATCHES "^VERSION_ID=[\"]?([a-zA-Z0-9_.-]+)[\"]?")
                    set(PACKAGE_DISTRO_VERSION ${CMAKE_MATCH_1})
                endif()
            endforeach()
        endif()
    endif()
    
    if(NOT PACKAGE_DISTRO_ID)
        set(PACKAGE_DISTRO_ID "generic")
    endif()
    
    message(STATUS "PackageDependencies: Detected '${PACKAGE_DISTRO_ID}' version '${PACKAGE_DISTRO_VERSION}'")
endif()

# ----------------- Mapping Logic -----------------

# Register a mapping: abstract_name -> concrete_package_name
# Usage: package_dependency_map(abstract_name "ubuntu 24.04" "pkg-name" "debian 12" "pkg-name-2" ...)
function(package_dependency_map abstract_name)
    # We expect pairs of "distro_ident" "package_name"
    # distro_ident can be "ubuntu" (matches all versions), "ubuntu-24.04" (specific), "generic"
    
    set(args ${ARGN})
    list(LENGTH args len)
    math(EXPR len_mod "${len} % 2")
    if(NOT len_mod EQUAL 0)
        message(FATAL_ERROR "package_dependency_map: Arguments must be pairs of 'distro_ident' 'package_name'")
    endif()
    
    foreach(i RANGE 0 ${len} 2)
        if(i EQUAL len)
            break()
        endif()
        math(EXPR j "${i} + 1")
        
        list(GET args ${i} distro_key)
        list(GET args ${j} pkg_name)
        
        string(TOLOWER "${distro_key}" distro_key_lower)
        # Normalize spaces to dashes if user used "ubuntu 24.04"
        string(REPLACE " " "-" key_norm "${distro_key_lower}")
        
        set_property(GLOBAL PROPERTY "PKG_MAP_${key_norm}_${abstract_name}" "${pkg_name}")
    endforeach()
endfunction()

# Internal: Resolve one abstract name
function(_resolve_abstract_pkg abstract_name output_var)
    # 1. Exact match: ID-VERSION (e.g., ubuntu-24.04)
    set(key_specific "${PACKAGE_DISTRO_ID}-${PACKAGE_DISTRO_VERSION}")
    get_property(mapping GLOBAL PROPERTY "PKG_MAP_${key_specific}_${abstract_name}")

    # 1.5. Major version match: ID-MAJOR (e.g., rhel-10 when version is 10.1)
    if(NOT mapping AND PACKAGE_DISTRO_VERSION MATCHES "^([^.]+)\\.")
        set(distro_major "${CMAKE_MATCH_1}")
        set(key_major "${PACKAGE_DISTRO_ID}-${distro_major}")
        get_property(mapping GLOBAL PROPERTY "PKG_MAP_${key_major}_${abstract_name}")
    endif()
    
    # 2. Distro match: ID (e.g., ubuntu)
    if(NOT mapping)
        get_property(mapping GLOBAL PROPERTY "PKG_MAP_${PACKAGE_DISTRO_ID}_${abstract_name}")
    endif()
    
    # 3. Generic/Fallback
    if(NOT mapping)
        get_property(mapping GLOBAL PROPERTY "PKG_MAP_generic_${abstract_name}")
    endif()
    
    if(NOT mapping)
        message(FATAL_ERROR "No package mapping found for dependency '${abstract_name}' on '${PACKAGE_DISTRO_ID} ${PACKAGE_DISTRO_VERSION}'")
    endif()
    
    set(${output_var} "${mapping}" PARENT_SCOPE)
endfunction()

# ----------------- Database of Known Mappings -----------------

# Boost Program Options
package_dependency_map(boost-program-options
    "ubuntu 24.04" "libboost-program-options1.83.0"
    "debian 13"    "libboost-program-options1.83.0"
    "rhel 10"      "boost-program-options"
)

# LLVM 19
package_dependency_map(llvm-19
    "ubuntu 22.04" "llvm-19"
    "ubuntu 24.04" "llvm-19"
    "ubuntu 25.04" "llvm-19"
    "debian 13"    "llvm-19"
    "rhel 10"      "llvm19"
)

# Clang 19
package_dependency_map(clang-19
    "ubuntu 22.04" "clang-19"
    "ubuntu 24.04" "clang-19"
    "ubuntu 25.04" "clang-19"
    "debian 13"    "clang-19"
    "rhel 10"      "clang19"
)


# LLD 19
package_dependency_map(lld-19
    "ubuntu 22.04" "lld-19"
    "ubuntu 24.04" "lld-19"
    "ubuntu 25.04" "lld-19"
    "debian 13"    "lld-19"
    "rhel 10"      "lld19"
)

package_dependency_map(ziptool
    "ubuntu 24.04" "ziptool"
    "debian 13"    "ziptool"
)

package_dependency_map(zipcmp
    "ubuntu 24.04" "zipcmp"
    "debian 13"    "zipcmp"
)

package_dependency_map(zipmerge
    "ubuntu 24.04" "zipmerge"
    "debian 13"    "zipmerge"
)

# ----------------- Resolution Walker -----------------

function(_scan_package_deps target visited_var runtime_result_var tool_result_var)
    set(worklist "${target}")
    set(visited ${${visited_var}})
    set(runtime_res ${${runtime_result_var}})
    set(tool_res ${${tool_result_var}})

    while(worklist)
        list(POP_FRONT worklist current)
        
        if(current IN_LIST visited)
            continue()
        endif()
        list(APPEND visited "${current}")

        if(TARGET "${current}")
            get_target_property(r_deps "${current}" PACKAGE_RUNTIME_DEPS)
            if(r_deps)
                list(APPEND runtime_res ${r_deps})
            endif()
            
            get_target_property(t_deps "${current}" PACKAGE_TOOL_DEPS)
            if(t_deps)
                list(APPEND tool_res ${t_deps})
            endif()
            
            set(libs "")
            get_target_property(type "${current}" TYPE)
            if(NOT type STREQUAL "INTERFACE_LIBRARY")
                get_target_property(link_libs "${current}" LINK_LIBRARIES)
                if(link_libs)
                    list(APPEND libs ${link_libs})
                endif()
            endif()
            get_target_property(interface_libs "${current}" INTERFACE_LINK_LIBRARIES)
            if(interface_libs)
                list(APPEND libs ${interface_libs})
            endif()

            foreach(lib IN LISTS libs)
                if(lib MATCHES "^[A-Za-z0-9_:-]+$")
                     if(TARGET "${lib}")
                        list(APPEND worklist "${lib}")
                     endif()
                endif()
            endforeach()
        endif()
    endwhile()

    set(${visited_var} "${visited}" PARENT_SCOPE)
    set(${runtime_result_var} "${runtime_res}" PARENT_SCOPE)
    set(${tool_result_var} "${tool_res}" PARENT_SCOPE)
endfunction()

function(get_package_dependencies output_var)
    set(root_targets ${ARGN})
    set(all_abstract_runtime "")
    set(all_abstract_tools "")
    set(visited "")

    foreach(tgt ${root_targets})
        _scan_package_deps("${tgt}" visited all_abstract_runtime all_abstract_tools)
    endforeach()
    
    if(all_abstract_runtime)
        list(REMOVE_DUPLICATES all_abstract_runtime)
    endif()
    if(all_abstract_tools)
        list(REMOVE_DUPLICATES all_abstract_tools)
    endif()
    
    set(final_list "")
    
    foreach(name ${all_abstract_runtime})
        _resolve_abstract_pkg("${name}" concrete)
        list(APPEND final_list "${concrete}")
    endforeach()
    
    foreach(name ${all_abstract_tools})
        _resolve_abstract_pkg("${name}" concrete)
        list(APPEND final_list "${concrete}")
    endforeach()
    
    if(final_list)
        list(REMOVE_DUPLICATES final_list)
    endif()
    
    set(${output_var} "${final_list}" PARENT_SCOPE)
endfunction()
