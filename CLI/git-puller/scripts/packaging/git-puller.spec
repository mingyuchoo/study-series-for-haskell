Name: git-puller
Version: %{release_version}
Release: 1
Summary: Batch Git pull CLI
License: BSD-3-Clause
Requires: git

%description
Git Puller updates eligible Git worktrees beneath a directory.

%install
mkdir -p "%{buildroot}"
cp -a "$GIT_PULLER_PACKAGE_ROOT/." "%{buildroot}/"

%files
/usr/bin/git-puller
