require "../src/oscillator"

class LotkaVolterra < DEVS::AtomicModel

  getter x = 1.0, y = 1.0

  @alpha = 5.2          # prey reproduction rate
  @beta = 3.4           # predator per prey mortality rate
  @gamma = 2.1          # predator mortality rate
  @delta = 1.4          # predator per prey reproduction rate
  @sigma = 0.0001       # euler integration

  def internal_transition
    dxdt = ((@x * @alpha) - (@beta * @x * @y))
    dydt = (-(@gamma * @y) + (@delta * @x * @y))

    @x += @sigma * dxdt
    @y += @sigma * dydt
  end
end

class Plotter
  include DEVS::Hooks::Notifiable
  include DEVS::TransitionObserver

  @file : File?

  SPACES = 30

  def initialize(model)
    DEVS::Hooks.notifier.subscribe(:before_simulation_initialization_hook, self)
    DEVS::Hooks.notifier.subscribe(:after_simulation_hook, self)
    model.add_observer(self)
  end

  def notify(hook)
    case hook
    when :before_simulation_initialization_hook
      @file = File.new("lotkavolterra.dat", "w+")
      @file.not_nil!.printf("%-#{SPACES}s %-#{SPACES}s %-#{SPACES}s\n", 't', 'x', 'y')
    when :after_simulation_hook
      @file.not_nil!.close
      @file = nil
    end
  end

  def update(model, kind)
    lotka = model as LotkaVolterra
    @file.not_nil!.printf("%-#{SPACES}s %-#{SPACES}s %-#{SPACES}s\n", lotka.time, lotka.x, lotka.y)
  end
end

opts = {
  :scheduler => :calendar_queue,
  :formalism => :pdevs,
  :duration => 20
}

model = LotkaVolterra.new(:LotkaVolterra)
Plotter.new(model)
sim = DEVS::Simulation.new(model, opts)

sim.simulate

puts "Dataset written to 'lotkavolterra.dat'."
puts "Run 'gnuplot -e \"plot 'lotkavolterra.dat' u 1:2 w l t 'preys', '' u 1:3 w l t 'predators'; pause -1;\"' to graph output"
