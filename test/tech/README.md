# tech tests

## mt19937 random number generator

The purpose of these tests is to assure that random generated numbers are cross platform consistent.

Two tests are included, running the same distributions used in Cell2Fire, but changing the origin of the random library.

One uses boost the other just std::random.

These tests can be run on https://github.com/fdobad/C2F-W/actions/workflows/mt19937-coordinator.yml and https://github.com/fdobad/C2F-W/actions/workflows/mt19937-coordinator-boost.yml manually as they have a workflow_dispatch directive.

On 2025-12-02 Only boost is cross platform!

When std::random get's consistent then boost dependency can be dropped easing the building times and dependencies!
