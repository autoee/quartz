require "./spec_helper"
require "./event_set_helper"

private struct EventSetTester
  @cq : EventSet(MySchedulable) = EventSet(MySchedulable).new(:calendar_queue)
  @lq : EventSet(MySchedulable) = EventSet(MySchedulable).new(:ladder_queue)
  @bh : EventSet(MySchedulable) = EventSet(MySchedulable).new(:binary_heap)
  @fh : EventSet(MySchedulable) = EventSet(MySchedulable).new(:fibonacci_heap)

  def test(&block : EventSet(MySchedulable) ->)
    it "(BinaryHeap)" { block.call(@bh) }
    # it "(CalendarQueue)" { block.call(@cq) }
    # it "(LadderQueue)" { block.call(@lq) }
    it "(FibonacciHeap)" { block.call(@fh) }
    # it "(MinList)" { block.call(@ml) }
  end
end

describe "EventSet" do
  describe "#size" do
    it "returns the number of planned events" do
      pes = EventSet(MySchedulable).new
      pes.plan_event(MySchedulable.new(1), Duration.new(1))
      pes.plan_event(MySchedulable.new(2), Duration.new(1))
      pes.plan_event(MySchedulable.new(3), Duration.new(3))
      pes.plan_event(MySchedulable.new(4), Duration.new(8))
      pes.size.should eq 4
    end
  end

  describe "#empty?" do
    it "indicates whether the event set is empty" do
      pes = EventSet(MySchedulable).new
      pes.empty?.should be_true

      pes.plan_event(MySchedulable.new(1), Duration.new(1))
      pes.plan_event(MySchedulable.new(2), Duration.new(1))
      pes.plan_event(MySchedulable.new(3), Duration.new(3))
      pes.plan_event(MySchedulable.new(4), Duration.new(8))
      pes.empty?.should be_false

      pes.pop_imminent_events
      pes.pop_imminent_events
      pes.pop_imminent_events
      pes.empty?.should be_true
    end
  end

  describe "#cmp_planned_phases" do
    context "at the start of new epoch" do
      it "compares two planned phases of same precision" do
        pes = EventSet(MySchedulable).new
        pes.cmp_planned_phases(Duration.new(1), Duration.new(2)).should eq(-1)
        pes.cmp_planned_phases(Duration.new(2), Duration.new(1)).should eq(1)
        pes.cmp_planned_phases(Duration.new(2), Duration.new(2)).should eq(0)
      end

      it "compares two planned phases of different precisions" do
        pes = EventSet(MySchedulable).new

        pes.cmp_planned_phases(Duration.new(15434, Scale::MILLI), Duration.new(17)).should eq(-1)
        pes.cmp_planned_phases(Duration.new(5), Duration.new(5000, Scale::MILLI)).should eq(0)
      end
    end

    context "within an epoch" do
      it "compares two planned phases of same precision" do
        ct = 87_234
        pes = EventSet(MySchedulable).new(TimePoint.new(ct))

        pes.cmp_planned_phases(Duration.new(ct + 1), Duration.new(ct + 2)).should eq(-1)
        pes.cmp_planned_phases(Duration.new(ct + 2), Duration.new(ct + 1)).should eq(1)
        pes.cmp_planned_phases(Duration.new(ct + 2), Duration.new(ct + 2)).should eq(0)
      end

      it "compares two planned phases of different precisions" do
        ct = 87_234
        pes = EventSet(MySchedulable).new(TimePoint.new(ct))

        pes.cmp_planned_phases(Duration.new(ct*1000 + 15434, Scale::MILLI), Duration.new(ct + 17)).should eq(-1)
        pes.cmp_planned_phases(Duration.new(ct + 5), Duration.new(ct*1000 + 5000, Scale::MILLI)).should eq(0)
      end

      it "compares two planned phases from different epochs" do
        pes = EventSet(MySchedulable).new(TimePoint.new(Duration::MULTIPLIER_MAX))
        pes.advance by: Duration.new(501)

        # 0 <=> MAX+499 (RHS in next epoch)
        pes.cmp_planned_phases(Duration.new(500), Duration.new(499)).should eq(-1)
        # 1 <=> MAX+499 (RHS in next epoch)
        pes.cmp_planned_phases(Duration.new(501), Duration.new(499)).should eq(-1)
        # MAX+449 <=> MAX+499 (both events in next epoch)
        pes.cmp_planned_phases(Duration.new(449), Duration.new(499)).should eq(-1)

        # MAX+449 <=> 5 (LHS in next epoch)
        pes.cmp_planned_phases(Duration.new(449), Duration.new(505)).should eq(1)

        # 5 <=> 5 (both in current epoch)
        pes.cmp_planned_phases(Duration.new(505), Duration.new(505)).should eq(0)
        # MAX+100 <==> MAX+100 (both in next epoch)
        pes.cmp_planned_phases(Duration.new(100), Duration.new(100)).should eq(0)
      end

      it "with flag, considers overflowed RHS in previous epoch instead of next epoch" do
        pes = EventSet(MySchedulable).new(TimePoint.new(Duration::MULTIPLIER_MAX))
        pes.advance by: Duration.new(501)

        # 0 <=> -1
        pes.cmp_planned_phases(Duration.new(500), Duration.new(499), rhs_in_current_epoch: true).should eq(1)
        # 1 <=> -1
        pes.cmp_planned_phases(Duration.new(501), Duration.new(499), rhs_in_current_epoch: true).should eq(1)

        # MAX+499 <=> -1
        pes.cmp_planned_phases(Duration.new(499), Duration.new(499), rhs_in_current_epoch: true).should eq(1)
      end
    end
  end

  describe "#duration_of" do
    it "returns the duration after which the specified event will occur relative to the current time" do
      pes = EventSet(MySchedulable).new
      ev = MySchedulable.new(1)
      pes.plan_event(ev, Duration.new(6889))

      pes.duration_of(ev).should eq(Duration.new(6889))

      pes.advance by: Duration.new(1234)
      pes.duration_of(ev).should eq(Duration.new(6889 - 1234))

      pes.advance
      pes.duration_of(ev).should eq(Duration.new(0))
    end

    it "returns a planned duration matching the original precision" do
      pes = EventSet(MySchedulable).new
      ev = MySchedulable.new(1)
      pes.plan_event(ev, Duration.new(1000))

      pes.duration_of(ev).should eq(Duration.new(1000))
      pes.duration_of(ev).precision.should eq(Scale.new(0))

      pes.advance by: Duration.new(999)
    end

    it "avoid rounding errors" do
      pes = EventSet(MySchedulable).new
      ev = MySchedulable.new(1)
      pes.plan_event(ev, Duration.new(1000))
      pes.advance by: Duration.new(999)

      pes.duration_of(ev).should eq(Duration.new(1))
      pes.duration_of(ev).precision.should eq(Scale.new(0))
    end

    it "handles events scheduled for the next epoch" do
      pes = EventSet(MySchedulable).new(:binary_heap)
      pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT - 6500)
      ev = MySchedulable.new(1)
      pes.plan_event(ev, Duration.new(10_234))

      pes.duration_of(ev).should eq(Duration.new(10_234))

      pes.advance by: Duration.new(1234)
      pes.duration_of(ev).should eq(Duration.new(10_234 - 1234))

      pes.advance
      pes.duration_of(ev).should eq(Duration.new(0))
    end
  end

  describe "#advance" do
    describe "with no arguments" do
      it "increase current time up to the imminent events" do
        pes = EventSet(MySchedulable).new
        pes.plan_event(MySchedulable.new(1), Duration.new(1))
        pes.plan_event(MySchedulable.new(2), Duration.new(5))

        pes.current_time.should eq(TimePoint.new(0))
        pes.imminent_duration.should eq(Duration.new(1))

        pes.advance
        pes.current_time.should eq(TimePoint.new(1))
        pes.imminent_duration.should eq(Duration.new(0))
        pes.pop_imminent_events
        pes.imminent_duration.should eq(Duration.new(4))

        pes.advance
        pes.current_time.should eq(TimePoint.new(5))
        pes.imminent_duration.should eq(Duration.new(0))
        pes.pop_imminent_events
      end
    end

    describe "given a duration" do
      it "raises if it exceed imminent duration" do
        pes = EventSet(MySchedulable).new
        pes.plan_event(MySchedulable.new(1), Duration.new(3))

        pes.current_time.should eq(TimePoint.new(0))
        pes.imminent_duration.should eq(Duration.new(3))
        expect_raises(BadSynchronisationError) do
          pes.advance by: Duration.new(3001, precision: Scale.new(-1))
        end
      end

      it "applies multiscale advancement" do
        pes = EventSet(MySchedulable).new(TimePoint.new(500111, Scale::FEMTO))
        pes.advance by: Duration.new(300, Scale::PICO)
        pes.current_time.should eq(TimePoint.new(800, Scale::PICO))
      end
    end

    describe "given a time point" do
      it "increase current time up to given time point" do
        pes = EventSet(MySchedulable).new(TimePoint.new(5, Scale::PICO))
        pes.advance until: TimePoint.new(982734, Scale::MILLI)
        pes.current_time.should eq(TimePoint.new(982734, Scale::MILLI))
      end

      it "raises if it exceed imminent duration" do
        pes = EventSet(MySchedulable).new
        pes.plan_event(MySchedulable.new(1), Duration.new(3))

        pes.current_time.should eq(TimePoint.new(0))
        pes.imminent_duration.should eq(Duration.new(3))

        expect_raises(BadSynchronisationError) do
          pes.advance until: TimePoint.new(3001, precision: Scale.new(-1))
        end
      end
    end
  end

  describe "#imminent_duration" do
    it "returns due duration before the next planned event(s) occur" do
      pes = EventSet(MySchedulable).new
      pes.imminent_duration.should eq(Duration::INFINITY)

      pes.plan_event(MySchedulable.new(1), Duration.new(1234, Scale::MICRO))
      pes.imminent_duration.should eq(Duration.new(1234, Scale::MICRO))

      pes.advance by: Duration.new(1, Scale::MILLI)
      pes.imminent_duration.should eq(Duration.new(234, Scale::MICRO))

      pes.advance by: Duration.new(234, Scale::MICRO)
      pes.imminent_duration.should eq(Duration.new(0, Scale::MICRO))
    end

    it "handles passage from an epoch to another" do
      pes = EventSet(MySchedulable).new
      pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT - 6500)

      pes.plan_event(MySchedulable.new(1), Duration.new(4358))
      pes.plan_event(MySchedulable.new(2), Duration.new(6500))
      pes.plan_event(MySchedulable.new(3), Duration.new(7634))

      pes.size.should eq(3)

      pes.imminent_duration.should eq(Duration.new(4358))
      pes.advance by: Duration.new(1500)
      pes.imminent_duration.should eq(Duration.new(4358 - 1500))
      pes.pop_imminent_event.should eq(1)

      pes.imminent_duration.should eq(Duration.new(6500 - 1500))
      pes.advance
      pes.imminent_duration.should eq(Duration.new(0))
      pes.pop_imminent_event.should eq(2)

      pes.imminent_duration.should eq(Duration.new(1134))
    end

    it "returns a planned duration matching current time precision" do
      pes = EventSet(MySchedulable).new
      pes.plan_event(MySchedulable.new(1), Duration.new(1000))
      pes.imminent_duration.should eq(Duration.new(1000))
      pes.imminent_duration.precision.should eq(Scale.new(0))

      pes.advance by: Duration.new(999)
      pes.imminent_duration.should eq(Duration.new(1))
      pes.imminent_duration.precision.should eq(Scale.new(0))
    end
  end

  describe "#cancel_event" do
    it "removes and returns the specified event" do
      pes = EventSet(MySchedulable).new
      ev1 = MySchedulable.new(1)
      ev2 = MySchedulable.new(2)
      pes.plan_event(ev1, Duration.new(5))
      pes.plan_event(ev2, Duration.new(7))

      pes.imminent_duration.should eq(Duration.new(5))
      pes.size.should eq(2)
      pes.cancel_event(ev1).should eq(1)
      pes.size.should eq(1)
      pes.imminent_duration.should eq(Duration.new(7))

      pes.cancel_event(ev2).should eq(2)
      pes.empty?.should be_true
    end

    it "removes and returns events occuring in the next epoch" do
      pes = EventSet(MySchedulable).new
      pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT / 2)
      ev = MySchedulable.new(1)
      pes.plan_event(ev, Duration.new(Duration::MULTIPLIER_MAX))

      pes.size.should eq(1)
      pes.cancel_event(ev).should eq(1)
      pes.size.should eq(0)
    end
  end

  describe "#pop_imminent_event" do
    it "deletes and returns the next imminent event" do
      pes = EventSet(MySchedulable).new
      pes.plan_event(MySchedulable.new(1), Duration.new(5))
      pes.plan_event(MySchedulable.new(2), Duration.new(7))
      pes.pop_imminent_event.should eq(1)
      pes.pop_imminent_event.should eq(2)
    end
  end

  describe "#pop_imminent_events" do
    it "deletes and returns the all imminent events" do
      pes = EventSet(MySchedulable).new
      pes.plan_event(MySchedulable.new(1), Duration.new(5))
      pes.plan_event(MySchedulable.new(2), Duration.new(7))
      pes.plan_event(MySchedulable.new(3), Duration.new(7))

      pes.pop_imminent_events.should eq([1])
      imm = pes.pop_imminent_events
      imm.should contain(2)
      imm.should contain(3)
    end
  end

  describe "#plan_event" do
    it "stores in the priority queue events occuring in the current epoch" do
      pes = EventSet(MySchedulable).new
      pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT / 2)

      pes.size.should eq(0)
      pes.plan_event(MySchedulable.new(1), Duration.new(500_234_848))
      pes.size.should eq(1)
      pes.@priority_queue.size.should eq(1)
    end

    it "stores in the priority queue events occuring in the next epoch" do
      pes = EventSet(MySchedulable).new
      pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT / 2)

      pes.size.should eq(0)
      pes.plan_event(MySchedulable.new(1), Duration.new(Duration::MULTIPLIER_MAX))
      pes.size.should eq(1)
      pes.@priority_queue.size.should eq(1)
    end
  end

  describe "passes up/down model with overlapping epochs" do
    n = 100_000

    max_tn = Duration::MULTIPLIER_MAX.to_i64
    prng = Random.new

    events = [] of Tuple(Duration, MySchedulable)
    ev_by_durations = Hash(Duration, Array(MySchedulable)).new { |h, k| h[k] = Array(MySchedulable).new }
    n.times do |i|
      duration = Duration.new(prng.rand(0i64..max_tn))
      ev = MySchedulable.new(i)
      events << {duration, ev}
      ev_by_durations[duration] << ev
    end
    sorted_durations = ev_by_durations.keys.sort

    EventSetTester.new.test do |pes|
      pes.advance by: Duration.new(Duration::MULTIPLIER_LIMIT / 2)

      # enqueue
      events.each { |d, ev| pes.plan_event(ev, d) }

      # dequeue
      sorted_durations.each do |duration|
        pes.imminent_duration.should eq(duration)

        imm = ev_by_durations[duration]
        imm.size.times do
          imm.should contain(pes.pop_imminent_event)
        end
      end
    end
  end

  describe "passes pdevs test with overlapping epochs" do
    n = 20_000
    steps = 20_000
    max_reschedules = 50
    max_tn = Duration::MULTIPLIER_MAX.to_i64
    seed = rand(Int64::MIN..Int64::MAX)
    sequence = Hash(String, Array(Duration)).new { |h, k| h[k] = Array(Duration).new }

    EventSetTester.new.test do |pes|
      prng = Random.new(seed)
      seq_key = pes.@priority_queue.class.name
      pes.advance by: Duration.new(Duration::MULTIPLIER_MAX - 2000)

      events = [] of Tuple(Duration, MySchedulable)
      n.times do |i|
        ev = MySchedulable.new(i)
        duration = Duration.new(prng.rand(0i64..max_tn))
        events << {duration, ev}
        pes.plan_event(ev, duration)
      end
      is_ladder = pes.is_a?(LadderQueue)

      pes.size.should eq(n)

      imm = Set(MySchedulable).new

      steps.times do
        if is_ladder
          (pes.size < n).should be_false
        else
          pes.size.should eq(n)
        end

        prio = pes.imminent_duration
        sequence[seq_key] << prio
        pes.advance by: prio
        pes.imminent_duration.zero?.should be_true

        imm.clear
        imm.concat(pes.pop_imminent_events)
        pes.imminent_duration.zero?.should be_false

        imm.each do |ev|
          pes.duration_of(ev).zero?.should be_true
          planned_duration = Duration.new(prng.rand(prio.multiplier..max_tn))

          _, ev = events[ev.int]
          events[ev.int] = {planned_duration, ev}

          unless planned_duration.infinite?
            pes.plan_event(ev, planned_duration)
          end
        end

        reschedules = prng.rand(max_reschedules)
        reschedules.times do
          index = prng.rand(events.size)
          d, ev = events[index]

          unless imm.includes?(ev)
            remaining = pes.duration_of(ev)
            remaining.zero?.should be_false

            ev_deleted = true
            if !d.infinite?
              c = pes.cancel_event(ev)

              if is_ladder && c.nil?
                ev_deleted = false
              else
                c.should_not be_nil
                ev.should eq(c)
              end
            end

            planned_duration = Duration.new(prng.rand(prio.multiplier..max_tn))
            events[index] = {planned_duration, ev}

            unless planned_duration.infinite?
              if ev_deleted || (!ev_deleted && !planned_duration.zero?)
                pes.plan_event(ev, planned_duration)
              end
            end
          end
        end
      end
    end

    ref_key = sequence.keys.first
    sequence.each_key do |key|
      next if key == ref_key
      it "event sequence of #{key} should be same as #{ref_key}" do
        sequence[key].should eq(sequence[ref_key])
      end
    end
  end
end
