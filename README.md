# crucible-ci

[![CI Actions Status](https://github.com/perftool-incubator/crucible-ci/workflows/run-core-crucible-ci/badge.svg)](https://github.com/perftool-incubator/crucible-ci/actions)

## Introduction

Crucible-CI is a Continuous Integration (CI) testing harness targeted at the [Crucible](https://github.com/perftool-incubator/crucible) performance automation and analysis framework.  Crucible is comprised of [many subprojects](https://github.com/perftool-incubator/crucible#subprojects) with each subproject having it's own repository.  As such, the primary goal of Crucible-CI is to be able to perform integration testing of a given subproject when changes to it are proposed via a pull request.

What this means is that when a pull request is submitted for a project that is a member of the Crucible family a working Crucible installation is created using the primary branch of all the other repositories and the proposed code for the specific repository that the pull request is for.  This installation is then used to perform integration testing of the pull request's changes combined with all of the other project's current upstream code.

The intent/goal here is that the upstream code in the primary branch for all repositories in the Crucible family of projects is ready for user delivery and consumption at all times.  This is a very ambitious goal but given the distribution model that Crucible uses, which is distribution of code updates via Git clone/pull from the upstream repositories, we believe it is the most appropriate target.

## Target Environment

Crucible-CI is primarily intended to be executed in the GitHub runner environment (both GitHub hosted and self-hosted runners).  However, some of its components can be executed outside of a GitHub runner environment in order to provide developers with the ability to integration test their changes prior to pull request submission.  More on this in the details below.

## Details

Crucible-CI is essentially a collection of [GitHub Actions](https://docs.github.com/en/actions) and [reusable GitHub workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows).

### Actions

Each action in Crucible-CI is unique and can be consumed in one or more [GitHub Action workflows](https://docs.github.com/en/actions/using-workflows/about-workflows).  Here is the current list of provided actions:

- Helper Actions
  - [build-controller](README.md#build-controller)
  - [check-controller-build](README.md#check-controller-build)
  - [clean-environment](README.md#clean-environment)
  - [get-job-parameters](README.md#get-job-parameters)
  - [get-releases](README.md#get-releases)
  - [get-repo-name](README.md#get-repo-name)
  - [get-scenarios](README.md#get-scenarios)
  - [get-userenvs](README.md#get-userenvs)
  - [install-crucible](README.md#install-crucible)
- Primary Actions
  - [integration-tests](README.md#integration-tests)

The actions are, for the most part, implemented as shell scripts that are provided to GitHub's workflow framework via `action.yml`.  The way in which they are aggregated together is very GitHub specific, but since they are simple shell scripts at their core we can potentially re-use them outside of the GitHub environment.  Where applicable/useful that is described below.

#### Helper Actions

These actions are used to provide information that can be used in the workflows in a variety of different ways.  These are not performing any testing of Crucible as it is meant to be used by an end user.

##### build-controller

The [build-controller](.github/actions/build-controller) action is used to build a Crucible controller image for use in one or more jobs.

##### check-controller-build

The [check-controller-build](.github/actions/check-controller-build) action is used to determine if changes to the main Crucible repository require the controller image to be rebuilt.

##### clean-environment

The [clean-environment](.github/actions/clean-environment) action is used to cleanup the runner environment after a run.  This really isn't necessary for GitHub hosted runners (since they are ephemeral) but self-hosted runners are not and must have their environments cleaned to avoid influencing future jobs.

##### get-job-parameters

The [get-job-parameters](.github/actions/get-job-parameters) action is used to generate a list of job parameters.  Each item in the list contains multiple parameters that are used to control what, how, and where the job is run.  This action is a future replacement for the [get-scenarios](README.md#get-scenarios) and [get-userenvs](README.md#get-userenvs) and combines their functionality.  This action is currently in active development.

#### get-releases

The [get-releases](.github/actions/get-releases) action is used to determine which releases need to be tested.  The action will always return the "upstream" release as needing testing, but it will do some additional inspection of the state of the repo and provided inputs to determine if additional releases need to be tested as well.  Currently that additional inspection amounts to this: if a new controller is being built for testing or the installer itself has changed then the supported releases will be tested as well since they can potentially be affected by those changes.

##### get-repo-name

The [get-repo-name](.github/actions/get-repo-name) action is used to extract a repository name from the `github.repository` context variable (which includes the owner/project name).

##### get-scenarios

The [get-scenarios](.github/actions/get-scenarios) action is used to determine what "scenarios" should be executed as part of a specific job (where a scenario is a combination of an endpoint and a benchmark).  The parameters are combined because they cannot be adequately evaluated in isolation with respect to the different runner environments (GitHub hosted vs. self hosted).

##### get-userenvs

The [get-userenvs](.github/actions/get-userenvs) action is used to look at a rickshaw repository to determine what the list of currently supported userenvs is.

##### install-crucible

The [install-crucible](.github/actions/install-crucible) action provides a reusable Crucible installation tool that can be configured to properly install upstream code for repositories not being tested while properly using the pull request code for the subproject being tested.

#### Primary Actions

These actions are where actual Crucible testing is performed.

##### integration-tests

The [integration-tests](.github/actions/integration-tests) action is where, as the name implies, the integration testing is performed.  This action has several different possible inputs, but all of them are optional.  By default it will run a very simple integration test based on the default values.  By specifying one or more of the available inputs the action can be "tuned" for the type of testing that is desired in the calling workflow.

The integration test is comprised of multiple shell scripts that perform different actions.  Some of these scripts are usually specific to the GitHub runner environment, such as [setup-ci-environment](.github/actions/integration-tests/setup-ci-environment) (since it performs a custon install of Crucible), while others can be used outside of the Github runner environment to perform testing in a development environment with an existing running Crucible installation.  An example of this is the use of [run-ci-stage1](.github/actions/integration-tests/run-ci-stage1) (which is the actual "test" in this action, the other scripts are primarily for setup and reporting) by the Crucible [`run-ci`](https://github.com/perftool-incubator/crucible/blob/bcdde354c751baff60f8cb9d68203113ec4c3439/bin/_help#L48) command.

### Workflows

There are two different kinds of workflows present in Crucible-CI.  They are:

- Reusable Workflows
  - [benchmark-crucible-ci](README.md#benchmark-crucible-ci)
  - [core-crucible-ci](README.md#core-crucible-ci)
- Runnable Workflows
  - [faux-crucible-ci](README.md#faux-crucible-ci)
  - [run-core-crucible-ci](README.md#run-core-crucible-ci)
  - [test-benchmark-crucible-ci](README.md#test-benchmark-crucible-ci)
  - [test-core-crucible-ci](README.md#test-core-crucible-ci)

#### Reusable Workflows

These workflows can be called from any Crucible subproject to easily provide a detailed CI test based on provided input.

##### benchmark-crucible-ci

The [benchmark-crucible-ci](.github/workflows/benchmark-crucible-ci.yaml) workflow is intended to be called from Crucible benchmark subprojects.  It limits its testing focus to benchmark specific jobs.

##### core-crucible-ci

The [core-crucible-ci](.github/workflows/core-crucible-ci.yaml) workflow is intended to be called by any of the core Crucible subprojects.  Some of the core subprojects required more detailed testing (such as controller building under certain conditions) which is implemented in this workflow.

#### Runnable Workflows

These workflows are what run as part of pull requests that are submitted against the Crucible-CI subproject itself.

##### faux-crucible-ci

The [faux-crucible-ci](.github/workflows/faux-crucible-ci.yaml) workflow is a "fake" workflow that is run when the pull request in question does not actually affect runtime behavior (such as documentation only changes).  It provides "null" jobs that satisfy Crucible-CI's GitHub branch protection rules.

##### run-core-crucible-ci

The [run-core-crucible-ci](.github/workflows/run-core-crucible-ci.yaml) workflow is used to execute the [core-crucible-ci](README.md#core-crucible-ci) reusable workflow with Crucible-CI being the target core subproject.  This workflow is an excellent example to base a workflow off of for use in another core subproject.

##### test-benchmark-crucible-ci

The [test-benchmark-crucible-ci](.github/workflows/test-benchmark-crucible-ci.yaml) workflow is used to test the [benchmark-crucible-ci](README.md#benchmark-crucible-ci) reusable workflow using different benchmarks.

##### test-core-crucible-ci

The [test-core-crucible-ci](.github/workflows/test-core-crucible-ci.yaml) workflow is used to test the [core-crucible-ci](README.md#core-crucible-ci) reusable workflow using different core subprojects.

## Testing Crucible-CI

Crucible-CI is a subproject in the Crucible family just like any other.  This means that Crucible-CI can be used to test itself when changes to it are proposed.  As mentioned above, it also means that Crucible-CI has an [embedded workflow](README.md#run-core-crucible-ci) implemented that demonstrates how its reusable workflows can be called.
