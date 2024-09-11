#----------------------------------------------------------------
# Generated CMake target import file for configuration "Release".
#----------------------------------------------------------------

# Commands may need to know the format version.
set(CMAKE_IMPORT_FILE_VERSION 1)

# Import target "Libssh2::libssh2_shared" for configuration "Release"
set_property(TARGET Libssh2::libssh2_shared APPEND PROPERTY IMPORTED_CONFIGURATIONS RELEASE)
set_target_properties(Libssh2::libssh2_shared PROPERTIES
  IMPORTED_LOCATION_RELEASE "${_IMPORT_PREFIX}/lib/libssh2.so.1.0.1"
  IMPORTED_SONAME_RELEASE "libssh2.so.1"
  )

list(APPEND _IMPORT_CHECK_TARGETS Libssh2::libssh2_shared )
list(APPEND _IMPORT_CHECK_FILES_FOR_Libssh2::libssh2_shared "${_IMPORT_PREFIX}/lib/libssh2.so.1.0.1" )

# Commands beyond this point should not need to know the version.
set(CMAKE_IMPORT_FILE_VERSION)
