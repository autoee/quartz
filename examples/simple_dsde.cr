require "../src/oscillator"

class OneTimeModel < DEVS::AtomicModel
  @sigma = 20

  def external_transition(messages)
    puts "#{name} received #{messages}."
  end

  def internal_transition
    puts "#{name} does something."
    @sigma = DEVS::INFINITY
  end
end

class BirthController < DEVS::DSDE::Executive
  def initialize(name)
    super(name)
    @sigma = 1
    @counter = 0
    @reverse = false
    add_output_port :birth, :death, :add_coupling, :remove_coupling
  end

  def internal_transition
    if @reverse
      remove_coupling_from_network(:out, from: :in, between: "model_0", and: "model_#{@counter}")
      remove_model_from_network("model_#{@counter}")
      @counter -= 1
      @sigma = DEVS::INFINITY
    else
      add_model_to_network(OneTimeModel.new("model_#{@counter}"))
      add_coupling_to_network(:out, to: :in, between: "model_0", and: "model_#{@counter}") if @counter > 0
      if @counter == 2
        @reverse = true
      else
        @counter += 1
      end
      @sigma = 5
    end
  end
end

class Grapher
  include DEVS::TransitionObserver

  def initialize(model, @simulation : DEVS::Simulation)
    model.add_observer(self)
  end

  def update(model, kind)
    if kind == :internal
      @simulation.generate_graph("dsde_#{@simulation.time.to_i}")
    end
  end
end

model = DEVS::DSDE::CoupledModel.new(:dsde, BirthController.new(:executive))
opts = {
    :maintain_hierarchy => true,
    :scheduler => :calendar_queue,
    :formalism => :pdevs,
    :duration => 35
}

simulation = DEVS::Simulation.new(model, opts)
simulation.generate_graph("dsde_0")
Grapher.new(model.executive, simulation)
simulation.simulate
