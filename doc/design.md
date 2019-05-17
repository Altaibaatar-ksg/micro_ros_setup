# The short story

My current verdict based on the [NuttX background information](nuttx_background.md)  is that we have to use the flat build mode for now. A consequence of this is that we also have to have the full micro-ROS app available during NuttX linkage.

Therefore, I propose basically keeping the current approach, where micro-ROS is compiled as part of NuttX, but make it easier for users to use, and also more efficient (by modifying the current Makefiles to only do what's necessary in each step).

# Assumptions

 * We want to use the colcon workflow for micro-ROS as well
 * We want to avoid having to modify the source packages to compile on micro-ROS (apart from general porting, of course, but the same code should compile on both regular ROS2 and micro-ROS, if it compiles on micro-ROS at all).
 
## Environment

 * Due to the cross-compilation, we are using two different workspaces: 1) for the code that ends up on the micro-controller (MCU_WS) 2) for the code that ends up on the host (HOST_WS)
 * To make it easier for the developer, and prevent mistakes, the MCU_WS is automatically created and maintained
  * All dependencies must be compiled from source for now. We can think about how to do pre-compilation later on (because it depends on the NuttX config, it's not as easy)
 
# Proposed Approach

*NOTE: This is proposed, not yet implemented*

  1) We have a configuration package that configures the firmware placed in the HOST_WS. This means
    * Which target board and configuration to use
    * Which packages to compile as apps
    * Example, with board `olimex-stm32-e407`, configuration `drive_base` and app `kobuki`:
    `add_microros_firmware(olimex-stm32-e407 drive_base kobuki)`

  1) On first run, this macro 
     a) creates a workspace directory, MCU_WS
     a) populates it with a NuttX checkout, by *symlinking* the apps packages, and all their dependent packages, from the HOST_WS
        * Take care to only symlink the package dirs, not the repositories, as the repositories might contain other, unneeded (and potentially problematic) packages
     a) checks out platform repositories that are not already present in the HOST_WS (and hence have not been symlinked, yet) into the MCU_WS
        * The list of necessary platform packages is contained within the micro_ros_build repository.
        * If the developer wants to work on these platform packages, they can be checked out in the HOST_WS, but they don't have to be.
        * If they are, they would also be compiled for the host. This may not be the intention of the developer, so we should provide them with a means to ignore them (e.g., through an example colcon.meta-file).
  1) Upon configuration of NuttX, a `toolchain.cmake` is placed in the MCU_WS, as well as a `colcon.meta` file to use it.
     * This is based on a Makefile rule in `apps/micro-ROS/`, dependent on `NuttX/.config`, so it will automatically by updated as well.
  1) When building the configuration package, it invokes a NuttX build in the MCU_WS. This NuttX build also performs the necessary build-steps for the MCU_WS and includes it during linking.

# Background

## Approaches

In general, micro-ROS needs to build rmw, rcl, their dependencies, the middleware (Micro-XRCE-DDS), and the type support for the micro-controller target.

### Drive build from NuttX

This is essentially the original approach

 * During the RTOS build, a toolchain file is created (like in `apps/uros` originally)
 * Using this toolchain file, the app Makefile invokes colcon build for a specified workspace, resulting in a bunch of static libraries
 * The app Makefile assembles all static libraries into NuttX's libapps.a
 * NuttX compile finishes as usual

#### Advantages

 * We have the toolchain file already before invoking colcon, so colcon works normally
 * We have NuttX directly checked out and can make modifications to it
 
#### Disadvantages

 * We have to tell NuttX where to find the workspace and which package contains our node (for dependency resolution)
 * We must never invoke colcon in the workspace manually, or else the toolchain file will be missing and it will be chaos
 * Either we use NuttX directly, then the build is unusual for the user and configuration has to be done manually
 * Or we drive the NuttX build using our cmake macro, then we essentially only have a single package in the repo, and have a colcon -> NuttX -> colcon build.
   
### External Project with repository list

 * We use an external project build, but modify the download step to use a repository list containing all dependencies of the current project
 * The repository list could be a) contained within the micro_ros_build package, or b) be a URL provided by the user of our macro or c) be auto-generated.

#### Advantages

 * By collecting building as an external project, we have full control over the build process
 * The initial call is in a package part of the user's regular workspace, so the user can still use colcon to *start* the process

#### Disadvantages

  * The source repositories are not normally checked out into the user's workspace. So, modifications to the repositories mentioned above will only be picked up once they are pushed back into the main repositories.
