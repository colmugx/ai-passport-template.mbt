///|
test "Stepper runs one step per 1/30 s delta on average" {
  let stepper = Stepper::new()
  // At exactly 60 Hz, deltas alternate 0 and 1 due steps.
  inspect(stepper.steps_due(1.0 / 60.0), content="0")
  inspect(stepper.steps_due(1.0 / 60.0), content="1")
  inspect(stepper.steps_due(1.0 / 60.0), content="0")
  inspect(stepper.steps_due(1.0 / 60.0), content="1")
  // A whole 1/12 s covers two steps at once.
  inspect(stepper.steps_due(1.0 / 12.0), content="2")
}

///|
test "Stepper banks sub-step remainders instead of dropping them" {
  let stepper = Stepper::new()
  inspect(stepper.steps_due(0.01), content="0")
  inspect(stepper.steps_due(0.01), content="0")
  inspect(stepper.steps_due(0.01), content="0")
  inspect(stepper.steps_due(0.01), content="1")
}

///|
test "Stepper caps catch-up after tab suspension" {
  let stepper = Stepper::new()
  // Ten seconds of elapsed time (suspended tab) runs at most
  // MAX_CATCHUP_STEPS = 5 steps and then discards the backlog.
  inspect(stepper.steps_due(10.0), content="5")
  // The next frame starts fresh, not deep in debt.
  inspect(stepper.steps_due(1.0 / 30.0), content="1")
  // Negative deltas are ignored.
  inspect(stepper.steps_due(-1.0), content="0")
}
