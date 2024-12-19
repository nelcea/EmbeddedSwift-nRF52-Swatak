@main
struct Main {
  static let game = Game()

  static func main() {

    func toggleButtonLed( _ port: UnsafePointer<device>?,
          _ callback: UnsafeMutablePointer<gpio_callback>?,
          _ pins: UInt32) {
      let c = Button<Context>.getContext(callback)
      if c.debounce() {
        let game = Main.game
        switch game.gameState {
          case .waiting:
            // In waiting state, pressing the button starts a count down to game start
            game.startCountDown()
          case .playing:
            // When playing, validate the user pressed the button of the lit up LED
            game.validatePress(position: c.buttonPosition)
          case .gameEnded, .starting:
            // During start count down and game end sequence, button presses do nothing
            break
        }
      }
    }

    let context1 = Context(position: .topLeft)
    let context2 = Context(position: .center)
    let context3 = Context(position: .bottomLeft)
    let context4 = Context(position: .bottomRight)
    let context5 = Context(position: .topRight)

    // Must retain a reference to the buttons, otherwise they get deallocated. This will generate unused warnings
    let btn1 = Button<Context>(gpio: &button1, context: context1, handle: toggleButtonLed)
    let btn2 = Button<Context>(gpio: &button2, context: context2, handle: toggleButtonLed)
    let btn3 = Button<Context>(gpio: &button3, context: context3, handle: toggleButtonLed)
    let btn4 = Button<Context>(gpio: &button4, context: context4, handle: toggleButtonLed)
    let btn5 = Button<Context>(gpio: &button5, context: context5, handle: toggleButtonLed)

    game.gameState = .waiting(position: .topRight)

    while true {
      Main.game.tick()
      k_msleep(1000)
    }
  }
}

// MARK: - Led class representing an LED connected to the board
// Using a class as we keep a reference to all the LEDs and we want to mutate their state

class Led {
  var gpio: UnsafePointer<gpio_dt_spec>

  var state: Bool {
    didSet {
      gpio_pin_set_dt(gpio, state ? 1 : 0)
    }
  }

  init(gpio: UnsafePointer<gpio_dt_spec>, state: Bool = false) {
    self.gpio = gpio
    self.state = state

    gpio_pin_configure_dt(gpio, GPIO_OUTPUT
                                | (state ? GPIO_OUTPUT_INIT_HIGH : GPIO_OUTPUT_INIT_LOW)
                                | GPIO_OUTPUT_INIT_LOGICAL)
  }
}

// MARK: - Position of buttons/leds on the board

enum Position: Int, CaseIterable {
  case topLeft = 0, center, bottomLeft, bottomRight, topRight
}

extension CaseIterable where Self: Equatable {
    func next() -> Self {
        let all = Self.allCases
        let idx = all.firstIndex(of: self)!
        let next = all.index(after: idx)
        return all[next == all.endIndex ? all.startIndex : next]
    }
}

// MARK: - Context used to associate a position and information used for debouncing to a button

class Context {
  let buttonPosition: Position

  var led: Led {
    Main.game.leds[buttonPosition.rawValue]
  }

  let threshold = 80
  var lastTime: UnsafeMutablePointer<Int64>
  var totalDelta: Int64 = 0

  init(position: Position) {
    self.buttonPosition = position
    lastTime = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
    lastTime.initialize(to: k_uptime_get())
  }

  /// Simple implementation of some form of debouncing for the button, locking it for some delay after first press is registered
  func debounce() -> Bool {
    totalDelta += k_uptime_delta(lastTime)
    if totalDelta > threshold {
      totalDelta = 0
      return true
    }
    return false
  }

  deinit {
    lastTime.deallocate()
  }
}

// MARK: - Game encapsulates the whole logic of the game

enum GameState {
  case waiting(position: Position)
  case starting(countDown: Int)
  case playing
  case gameEnded(slash: Bool, countDown: Int)
}

class Game {
  static let endSequenceTime = 10

  let leds = [Led(gpio: &led1), Led(gpio: &led2), Led(gpio: &led3), Led(gpio: &led4), Led(gpio: &led5)]
  var currentPosition: Position?

  var gameState = GameState.waiting(position: .topLeft)

  var totalTaps: Int32 = 0
  var correctTaps: Int32 = 0
  
  var lowestTime = Int32.max
  var highestTime: Int32 = 0
  var totalTime: Int32 = 0

  var lastTime: UnsafeMutablePointer<Int64>

  var timer: Timer<Game>?

  init() {
    lastTime = UnsafeMutablePointer<Int64>.allocate(capacity: 1)
    lastTime.initialize(to: k_uptime_get())
  }

  /// Turn off LED at current position and randomly picks a different one to light up
  func nextPosition() {
    if let currentPosition {
      leds[currentPosition.rawValue].state = false
    }
    var nextPosition: Position
    repeat {
      nextPosition = Position.allCases.randomElement()!
    } while nextPosition == currentPosition
    currentPosition = nextPosition
    if let currentPosition {
      leds[currentPosition.rawValue].state = true
    }
  }

  /// Verifies that user has tapped button with lit LED and if so lits up a new one
  func validatePress(position: Position) {
    totalTaps += 1
    if position == currentPosition {
      correctTaps += 1
      let delta = Int32(k_uptime_delta(lastTime))
      if delta > highestTime {
        highestTime = delta
      }
      if delta < lowestTime {
        lowestTime = delta
      }
      totalTime += delta

      nextPosition()
    }
  }

  func reset() {
    totalTaps = 0
    correctTaps = 0
    lowestTime = Int32.max
    highestTime = 0
    totalTime = 0
    lastTime.pointee = k_uptime_get()
  }

  func startCountDown() {
    gameState = .starting(countDown: 3)
    leds[Position.topLeft.rawValue].state = true
    leds[Position.center.rawValue].state = true
    leds[Position.bottomRight.rawValue].state = true
    leds[Position.bottomLeft.rawValue].state = false
    leds[Position.topRight.rawValue].state = false
  }

  func start() {
    leds[Position.topLeft.rawValue].state = false
    gameState = .playing
    timer = Timer<Game>(userData: self, delay: 30_000) { timer in
      Timer<Game>.getUserData(timer).endGame()
    }

    reset()
    nextPosition()
  }

  func endGame() {
    // Don't do anything time consuming here, it's executed in ISR, change status and print the stats in main loop
    gameState = .gameEnded(slash: true, countDown: Self.endSequenceTime)
    timer = nil
  }

  /// Called at regular interval (1 sec) to handle the different waiting, starting and ending animations
  func tick() {
    switch gameState {
    case .waiting(let position):
      leds[position.rawValue].state = false
      let nextPosition = position.next()
      leds[nextPosition.rawValue].state = true
      gameState = .waiting(position: nextPosition)

    case .starting(let countDown):
      switch countDown {
        case 0:
          start()
        case 1:
          leds[Position.topLeft.rawValue].state = false
        case 2:
          leds[Position.center.rawValue].state = false
        case 3:
          leds[Position.bottomRight.rawValue].state = false
        default:
          break
      }
      if countDown > 0 {
        gameState = .starting(countDown: countDown - 1)
      }
    case .playing:
      break
    case .gameEnded(let slash, let countDown):
      if countDown > 0 {
        if countDown == Self.endSequenceTime {
          print("Game ended")
          print("Total taps: \(totalTaps)")
          print("Correct taps: \(correctTaps)")
          print("Fastest reaction time: \(lowestTime)ms")
          print("Slowest reaction time: \(highestTime)ms")

          if correctTaps != 0 {
            let averageTime = Int(Double(totalTime) / Double(correctTaps))
            print("Average reaction time: \(averageTime)ms")
          }
        }
        gameState = .gameEnded(slash: !slash, countDown: countDown - 1)
        leds[Position.topLeft.rawValue].state = slash ? false : true
        leds[Position.topRight.rawValue].state = slash ? true : false
        leds[Position.center.rawValue].state = true
        leds[Position.bottomLeft.rawValue].state = slash ? true : false
        leds[Position.bottomRight.rawValue].state = slash ? false : true
      } else {
        gameState = .waiting(position: .topLeft)
        leds[Position.topLeft.rawValue].state = true
        leds[Position.topRight.rawValue].state = false
        leds[Position.center.rawValue].state = false
        leds[Position.bottomLeft.rawValue].state = false
        leds[Position.bottomRight.rawValue].state = false
      }
    }
  }
}
