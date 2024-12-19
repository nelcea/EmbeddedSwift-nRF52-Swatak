typealias GpioCallbackHandler = @convention(c) (
  _ port: UnsafePointer<device>?,
  _ callback: UnsafeMutablePointer<gpio_callback>?,
  _ pins: UInt32
) -> Void

struct Button<T: AnyObject>: ~Copyable {
  var gpio: UnsafePointer<gpio_dt_spec>
  var handle: GpioCallbackHandler?

  var context: T

  var pin_cb_data: UnsafeMutablePointer<extended_callback>

  static func getContext(_ callback: UnsafeMutablePointer<gpio_callback>?) -> T {
    return Unmanaged.fromOpaque(container_of(callback).pointee.context).takeUnretainedValue()
  }

  init(gpio: UnsafePointer<gpio_dt_spec>, context: T, handle: GpioCallbackHandler?) {
   	if (!gpio_is_ready_dt(gpio)) {
  		print("Error init button")
	  }

    self.gpio = gpio
    self.context = context
    self.pin_cb_data = UnsafeMutablePointer<extended_callback>.allocate(capacity: 1)

    self.pin_cb_data.pointee.context = Unmanaged.passUnretained(context).toOpaque()
    self.handle = handle

    var ret = gpio_pin_configure_dt(self.gpio, GPIO_INPUT)
    if ret < 0 {
      print("Error \(ret)")
    }

    ret = gpio_pin_interrupt_configure_dt(self.gpio, (GPIO_INT_ENABLE | GPIO_INT_LEVELS_LOGICAL | GPIO_INT_EDGE | GPIO_INT_HIGH_1))
    if ret < 0 {
      print("Error \(ret)")
    }

	  gpio_init_callback(&self.pin_cb_data.pointee.pin_cb_data, self.handle, (UInt32(1) << self.gpio.pointee.pin))

	  ret = gpio_add_callback(self.gpio.pointee.port, &self.pin_cb_data.pointee.pin_cb_data)

    if ret < 0 {
      print("Error \(ret)")
    }
  }

  deinit {
    gpio_remove_callback(self.gpio.pointee.port, &self.pin_cb_data.pointee.pin_cb_data)
    self.pin_cb_data.deallocate()
  }
}
