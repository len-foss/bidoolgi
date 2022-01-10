# bidoolgi 비둘기
Odoo project management scripts
![Logo](bidoolgi.webp)

Bidoolgi helps managing Odoo projects by providing a unified way to start, test, and manage them.
The aim is to be most efficient while have very little to type and remember.

This is a terminal-based workflow,
relying on the Acsone methodology and toolset (pip installs, click-odoo, etc).
However it is simple enough to be adapted to remove these dependencies,
and serve as inspiration for a similar workflow.

## Requirements

It is assumed you have installed `virtualenvwrapper`.
All functions in the `o` script depend on having a project set up.
Check `acsoo` - new project to use a template if you need one.
You also need all Python versions you intend to use.

## Install

Add the content of `bashrc.sh` to your `.bashrc`.
Because of the way `virtualenvwrapper` works, these commands cannot be executed in a subshell.
Copy the `o.sh` script in a folder on your path as `o`.
Make sure it is executable, using `chmod +x` if needed.
In Ubuntu, `~/bin` is on your path, in doubt check with `echo $PATH`.

Finally, add a global rule to ignore your local `.odoorc`.
To do so, first add the necessary lines to your `.gitconfig`:
```
[core]
    editor = vim
    excludesfile = ~/.gitignore
```
Then, you just need to add a `.odoorc` line to your global `gitignore`.

## Usage:

We assume you already have a project setup.
Let's say it is `odoo-project`, intended to run in python 3.8.
Create your virtualenv with: `m 3.8`.
Next time you'll need to activate the virtualenv, just type `w`.
The virtualenv has been created with the folder name as name,
so we don't need to type it again to find it.
To install requirements, use: `o setup`.
It will pull all dependencies, along with `pudb` and `ipython`.

Starting from there, there are 3 main workflows:
- a working database, that will typically be obtained from a dump.
- a testing database, that will allow to run module tests in post-install
- a series of module specific databases, to run tests on a specific module

### Working database

This database is named `odoo-project`.
Typically, you would restore a dump for this, so there isn't any specific command to initialize it.
After you restore a dump, you can perform sanitizing operations with `o clean`.
Absent of a dump, you can create it using the install command below.

Run it with `o r`, or launch a shell session with `o rs`.
You can install a module `module` by running `o i module`.
You can upgrade a module `module` by running `o u module`.
To upgrade all modules that need it, run `o up` (it may take much longer).

To install a new dependency or sync requirements, use `o pu addon`.
To make a release, use `o bumpp` (to make a pach release),
`o bumpm` for a minor and `o bumpM` for a major bump.

You can generate the project documentation using `pigeoo` by running
`o doc hat_module_1,hat_module_2`.
Note that while Python2 projects are technically not supported, it still
generates a working documentation for module (co-)dependencies.

### Test database

You can install a module `module` by running `o it module`.
Test it with `o t module`.
To upgrade all modules, use `o upt`.
That should be sufficient!

### Module-specific Test databases

Running the tests with only the dependencies installed
ensure that the process works from scratch, and help catch undeclared dependency.

Initialize a database with `o itt module`.
Then, run the tests with `o tt module`.

To clean up all module-specific databases, run `o dropdbs`.

## Miscellaneous

You can copy a database with `copydb source target_name`.

To drop all databases according to a (grep) pattern, use `ddb pattern` (use at your own risk, or modify `xargs` options before).
Note that this is a command working outside of a project venv, so it will not drop the filestore for Odoo databases dropped this way.
