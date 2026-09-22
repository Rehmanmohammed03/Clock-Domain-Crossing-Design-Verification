# Clock Domain Crossing (CDC) Design & Verification

A SystemVerilog **Clock Domain Crossing (CDC) design and verification project** focused on safely transferring control signals and events between asynchronous clock domains.

The project implements and verifies multiple CDC architectures, including **2-Flip-Flop (2FF), pulse, toggle, reset, and request/acknowledge synchronizers**. Self-checking randomized testbenches were developed to evaluate behavior across different clock-frequency ratios and identify issues such as **metastability exposure, lost events, duplicate events, reset failures, and incorrect handshake sequencing**.

## Overview

Signals crossing between independent clock domains can become unstable due to asynchronous timing relationships. This project explores common CDC techniques for safely transferring signals while maintaining data integrity and event correctness.

The verification environment tests each synchronizer under different clock relationships, including:

* Fast-to-slow clock crossings
* Slow-to-fast clock crossings
* Different clock-frequency ratios
* Independent clock phases
* Reset assertion and deassertion
* Repeated event generation
* Randomized input timing

```text
             Clock Domain A
                  |
                  | Signal / Event
                  v
        +----------------------+
        |      CDC Logic       |
        |                      |
        |  2FF Synchronizer    |
        |  Pulse Synchronizer  |
        |  Toggle Synchronizer |
        |  Reset Synchronizer  |
        |  Req/Ack Handshake   |
        +----------------------+
                  |
                  | Synchronized Signal
                  v
             Clock Domain B
```

## CDC Architectures

### 2-Flip-Flop Synchronizer

A standard two-stage synchronizer was implemented for transferring **single-bit level signals** between asynchronous clock domains.

```text
Async Signal
     |
     v
+----------+
| Flip-Flop |  Clock Domain B
+----------+
     |
     v
+----------+
| Flip-Flop |
+----------+
     |
     v
Synchronized Signal
```

The first flip-flop samples the asynchronous input, while the second stage provides additional settling time before the signal is used by downstream logic.

### Pulse Synchronizer

A pulse-based CDC architecture was implemented to transfer events between clock domains.

The design was tested under both:

* Fast-to-slow crossings
* Slow-to-fast crossings

Testing specifically examined whether short pulses could be **lost, duplicated, or incorrectly detected** depending on the relative clock frequencies.

### Toggle Synchronizer

A toggle-based architecture was implemented to transfer discrete events across clock domains.

Instead of transferring the pulse width directly, the source domain changes the state of a toggle signal whenever an event occurs.

```text
Source Domain                 Destination Domain

 Event
   |
   v
+--------+                  +--------+
| Toggle | ---- Async ----> |  2FF   |
+--------+                  +--------+
                                |
                                v
                         Edge Detection
                                |
                                v
                         Destination Event
```

This approach allows an event to remain represented until the destination domain observes the state transition.

### Reset Synchronizer

Reset synchronization logic was developed to safely distribute reset behavior across asynchronous clock domains.

Verification included:

* Reset assertion
* Reset release
* Clock-domain independence
* Recovery of synchronized logic following reset

Special attention was given to reset behavior around clock edges.

### Request/Acknowledge Synchronizer

A request/acknowledge handshake was implemented for reliable event transfer when the source must receive confirmation that the destination has processed a request.

```text
        Source Domain                  Destination Domain

        +---------+                    +---------+
        | Request | -----------------> | Request |
        +---------+                    +---------+
             ^                              |
             |                              v
             |                         Process Event
             |                              |
             |                              v
        +---------+                    +---------+
        |   ACK   | <----------------- |   ACK   |
        +---------+                    +---------+
```

The handshake was verified for correct request and acknowledgement sequencing, including asynchronous clock relationships.

## Verification Environment

The project uses **self-checking SystemVerilog testbenches** to automatically determine whether the CDC designs behave correctly.

Rather than relying solely on waveform inspection, the testbenches monitor expected and observed behavior and flag incorrect results automatically.

### Verification Flow

```text
             Randomized Stimulus
                     |
                     v
             +---------------+
             | SystemVerilog |
             |  Testbench    |
             +---------------+
                     |
                     v
             +---------------+
             |   CDC DUT     |
             +---------------+
                     |
                     v
              Observed Output
                     |
                     v
             +---------------+
             |   Reference   |
             |    Checker    |
             +---------------+
                     |
                     v
              PASS / FAIL
```

## Randomized Testing

The testbenches generate randomized scenarios to exercise CDC behavior under different timing conditions.

Clock relationships were varied across multiple frequency ratios to expose timing-dependent behavior.

Example scenarios include:

```text
Scenario 1:
Source Clock      = Fast
Destination Clock = Slow

Scenario 2:
Source Clock      = Slow
Destination Clock = Fast

Scenario 3:
Source Clock      = Similar Frequency
Destination Clock = Similar Frequency

Scenario 4:
Randomized Clock Phase Relationships
```

Randomized event timing was also used to increase coverage of boundary conditions.

## Verification Goals

The verification environment evaluates several key CDC properties:

### Signal Synchronization

Verify that asynchronous control signals eventually appear correctly in the destination clock domain.

### Lost Events

Verify that events are not unintentionally dropped when the source and destination clocks operate at different frequencies.

### Duplicate Events

Verify that a single source event produces exactly one destination event.

### Reset Behavior

Verify correct initialization and recovery when reset is asserted or released asynchronously relative to the clocks.

### Handshake Correctness

For request/acknowledge CDC logic, verify that:

```text
Request
   |
   v
Destination Receives Request
   |
   v
Request Processed
   |
   v
Acknowledgement Generated
   |
   v
Source Receives Acknowledgement
```

No request should be acknowledged incorrectly, and the source should not issue a new transaction before the previous handshake has completed.

## Waveform Debugging

**ModelSim** was used to inspect internal signals and debug CDC behavior.

Waveforms were analyzed for:

* Synchronizer stage transitions
* Clock-domain relationships
* Pulse detection
* Toggle transitions
* Reset assertion/deassertion
* Request/acknowledge sequencing
* Event latency
* Lost or duplicate events

Example debugging flow:

```text
Unexpected Output
       |
       v
Inspect Destination Output
       |
       v
Trace Synchronizer Stages
       |
       v
Inspect Source Event
       |
       v
Compare Clock Relationships
       |
       v
Identify CDC Timing Issue
       |
       v
Modify RTL / Testbench
       |
       v
Re-run Simulation
```

## Design Considerations

### Metastability

Asynchronous signals can violate setup and hold requirements when sampled by the destination clock.

The 2FF synchronizer provides additional settling time between the asynchronous input and the logic consuming the synchronized signal.

### Pulse Width

A pulse that is shorter than the destination clock period may not be sampled at all.

This project therefore compares pulse-based approaches with toggle and handshake-based event transfer methods.

### Clock Frequency Differences

CDC behavior depends heavily on the relationship between source and destination clock frequencies.

Testing both **fast-to-slow** and **slow-to-fast** crossings helps expose failures that may not appear when the clocks have similar frequencies.

### Reset Ordering

Reset release can also create CDC-related issues if different domains leave reset at different times.

Reset synchronization was therefore treated as a separate CDC problem rather than assuming a global reset was inherently safe.

## Verification Features

* Self-checking SystemVerilog testbenches
* Randomized stimulus generation
* Multiple asynchronous clock configurations
* Multiple clock-frequency ratios
* Fast-to-slow CDC testing
* Slow-to-fast CDC testing
* Reset sequencing tests
* Event loss detection
* Duplicate event detection
* Request/acknowledge protocol checking
* Waveform-based debugging
* Automated PASS/FAIL checking

## Technologies

**HDL / RTL**

* SystemVerilog
* RTL Design
* Sequential Logic
* Finite State Machines
* Clock Domain Crossing
* Synchronizer Design

**CDC Techniques**

* 2FF Synchronizer
* Pulse Synchronizer
* Toggle Synchronizer
* Reset Synchronizer
* Request/Acknowledge Handshake

**Verification**

* SystemVerilog Testbenches
* Randomized Testing
* Self-Checking Testbenches
* Reference Models / Checkers
* Waveform Debugging
* ModelSim

## Results

The project successfully demonstrated and verified multiple CDC architectures under asynchronous clock relationships.

Testing validated:

* Correct signal synchronization
* Reliable event transfer
* Reset behavior
* Fast-to-slow crossings
* Slow-to-fast crossings
* Detection of lost events
* Detection of duplicate events
* Correct request/acknowledge sequencing

The project also demonstrated how randomized simulation and waveform analysis can be used to identify timing-dependent RTL bugs that may not appear under a single fixed clock configuration.

## Skills Demonstrated

* SystemVerilog RTL Design
* Clock Domain Crossing
* CDC Synchronizer Design
* Digital Logic Design
* Hardware Verification
* Self-Checking Testbenches
* Randomized Verification
* Testbench Architecture
* Waveform Debugging
* ModelSim
* Metastability-Aware Design
* Reset Synchronization
* Handshake Protocols
* Timing-Corner Testing
* RTL Debugging

## Future Improvements

Potential extensions include:

* Adding SystemVerilog Assertions (SVA)
* Functional coverage collection
* Assertion-based CDC checking
* Constrained-random verification
* UVM-based verification environment
* Automated regression testing
* Formal verification of synchronizer properties
* Additional multi-bit CDC architectures
* Asynchronous FIFO implementation
* Coverage-driven verification

Computer Engineering
McMaster University
