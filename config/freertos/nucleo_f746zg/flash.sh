OLIMEX_EXTENSIONS_DIR=$FW_TARGETDIR/freertos_apps/microros_nucleo_f746zg_extensions

pushd $OLIMEX_EXTENSIONS_DIR > /dev/null

  if [ -f build/micro-ROS.bin ]; then
    echo "Flashing firmware for $RTOS platform $PLATFORM"

      if lsusb -d 15BA:002a; then
        PROGRAMMER=interface/ftdi/nucleo-arm-usb-tiny-h.cfg
      elif lsusb -d 15BA:0003;then
        PROGRAMMER=interface/ftdi/nucleo-arm-usb-ocd.cfg
      elif lsusb -d 15BA:002b;then
        PROGRAMMER=interface/ftdi/nucleo-arm-usb-ocd-h.cfg
      else
        echo "Error. Unsuported OpenOCD USB programmer"
        exit 1
      fi

      openocd -f $PROGRAMMER -f target/stm32f7x.cfg -c init -c "reset halt" -c "flash write_image erase build/micro-ROS.bin 0x08000000" -c "reset" -c "exit"
  else
    echo "build/micro-ROS.bin not found: please compile before flashing."
  fi

popd > /dev/null
