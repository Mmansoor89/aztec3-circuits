include(ExternalProject)

# 🛡️ PATH SAFETY: Ensure BBERG_DIR is an absolute path to avoid relative path hell 
# inside ExternalProject execution.
get_filename_component(BBERG_ABS_DIR ${BBERG_DIR} ABSOLUTE)

# 🏗️ CONFIGURATION: Determine build directories and targets based on architecture.
if (WASM)
    set(BBERG_BUILD_DIR ${BBERG_ABS_DIR}/build-wasm)
    set(BBERG_TARGETS --target barretenberg --target env --target primitives.wasm)
else()
    set(BBERG_BUILD_DIR ${BBERG_ABS_DIR}/build)
    set(BBERG_TARGETS --target barretenberg --target env)
endif()

# Set default preset if not provided
if(NOT CMAKE_BBERG_PRESET)
    set(CMAKE_BBERG_PRESET default)
endif()

# 📦 EXTERNAL PROJECT DEFINITION
# We use BUILD_IN_SOURCE because we are relying on 'cmake --preset' to handle 
# the build directory generation internally within barretenberg's structure.
ExternalProject_Add(Barretenberg
    SOURCE_DIR ${BBERG_ABS_DIR}
    BUILD_IN_SOURCE TRUE
    BUILD_ALWAYS TRUE  # ⚠️ Performance Note: This checks the sub-project on every build.
    UPDATE_COMMAND ""  # Prevent git fetch/pull on every build
    INSTALL_COMMAND "" # We consume from build dir, no install needed
    
    # Pass necessary flags to the sub-project
    CONFIGURE_COMMAND ${CMAKE_COMMAND} --preset ${CMAKE_BBERG_PRESET} 
        -DSERIALIZE_CANARY=${SERIALIZE_CANARY} 
        -DENABLE_ASAN=${ENABLE_ASAN} 
        -DCMAKE_BUILD_TYPE=${CMAKE_BUILD_TYPE} 
        -DUSE_TURBO=${USE_TURBO}
        
    BUILD_COMMAND ${CMAKE_COMMAND} --build --preset ${CMAKE_BBERG_PRESET} ${BBERG_TARGETS}
    
    # Ninja generator requirement: explicit byproducts
    BUILD_BYPRODUCTS 
        ${BBERG_BUILD_DIR}/lib/libbarretenberg.a 
        ${BBERG_BUILD_DIR}/lib/libenv.a
)

# 🚀 MODERN CMAKE: IMPORTED TARGETS
# Instead of global include_directories(), we attach the include path 
# directly to the library target.

# --- Library: barretenberg ---
add_library(barretenberg STATIC IMPORTED)
set_target_properties(barretenberg PROPERTIES 
    IMPORTED_LOCATION ${BBERG_BUILD_DIR}/lib/libbarretenberg.a
    # ✨ MAGIC: Only targets linking to 'barretenberg' will see these headers.
    INTERFACE_INCLUDE_DIRECTORIES ${BBERG_ABS_DIR}/src 
)
add_dependencies(barretenberg Barretenberg)

# --- Library: env ---
add_library(env STATIC IMPORTED)
set_target_properties(env PROPERTIES 
    IMPORTED_LOCATION ${BBERG_BUILD_DIR}/lib/libenv.a
    # Env likely needs the same headers available
    INTERFACE_INCLUDE_DIRECTORIES ${BBERG_ABS_DIR}/src
)
add_dependencies(env Barretenberg)
