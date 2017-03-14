require './lib/ostools.rb'

name 'paas-agent'

local_agent_repo = ENV['LOCAL_AGENT_REPO']
if local_agent_repo.nil? || local_agent_repo.empty?
  source git: 'https://github.com/kexibuaijifen/paas-agent.git'
else
   #For local development
  source path: ENV['LOCAL_AGENT_REPO']
end

agent_branch = ENV['AGENT_BRANCH']
if agent_branch.nil? || agent_branch.empty?
  default_version 'master'
else
  default_version agent_branch
end

relative_path 'paas-agent'

build do
  ship_license 'https://raw.githubusercontent.com/DataDog/dd-agent/master/LICENSE'
  #这里要修改，证书
  # Agent code
  mkdir  "#{install_dir}/agent/"
  mkdir  "#{install_dir}/run/"
  copy 'checks.d', "#{install_dir}/agent/"
  copy 'checks', "#{install_dir}/agent/"
  copy 'dogstream', "#{install_dir}/agent/"
  #copy 'resources', "#{install_dir}/agent/"#这个在dd-agent5.5以后版本被移除
  copy 'utils', "#{install_dir}/agent/"
  command "cp *.py #{install_dir}/agent/"
  copy 'datadog-cert.pem', "#{install_dir}/agent/"
  copy '/root/paas-agent/checks.d', "#{install_dir}/agent/"
  copy '/root/paas-agent/checks', "#{install_dir}/agent/"
  copy '/root/paas-agent/dogstream', "#{install_dir}/agent/"
  #copy 'resources', "#{install_dir}/agent/"
  copy '/root/paas-agent/utils', "#{install_dir}/agent/"
  command "cp /root/paas-agent/*.py #{install_dir}/agent/"
  copy '/root/paas-agent/paasinsight-cert.pem', "#{install_dir}/agent/paasinsight-cert.pem"
  #这里的证书要修改



  if linux?
    # Configuration files
    mkdir '/etc/paas-agent'
    if redhat?
      copy '/root/paas-agent/packaging/centos/paas-agent.init', '/etc/rc.d/init.d/paas-agent'
    end

    if suse? || debian?
      if debian?
        sys_type = 'debian'
        systemd_directory = '/lib/systemd/system'
      elsif suse?
        sys_type = 'suse'
        systemd_directory = '/usr/lib/systemd/system'
      end
      copy "/root/paas-agent/packaging/#{sys_type}/paas-agent.init", '/etc/init.d/paas-agent'
      mkdir systemd_directory
      copy '/root/paas-agent/packaging/debian/paas-agent.service', "#{systemd_directory}/paas-agent.service"
      copy '/root/paas-agent/packaging/debian/start_agent.sh', '/opt/paas-agent/bin/start_agent.sh'
      command 'chmod 755 /opt/paas-agent/bin/start_agent.sh'
    end

    # Use a supervisor conf with go-metro on 64-bit platforms only
    if ohai['kernel']['machine'] == 'x86_64'
      copy '/root/paas-agent/packaging/supervisor.conf', '/etc/paas-agent/supervisor.conf'
    else
      copy '/root/paas-agent/packaging/supervisor_32.conf', '/etc/paas-agent/supervisor.conf'
    end
<<<<<<< HEAD
=======
    copy '/root/paas-agent/paasinsight.conf.example', '/etc/paas-agent/paasinsight.conf.example'
    copy '/root/paas-agent/conf.d', '/etc/paas-agent/'
>>>>>>> 3114d50229c969f1b7614cdace9b2ba9a42f10cd
    mkdir '/etc/paas-agent/checks.d/'
    command 'chmod 755 /etc/init.d/paas-agent'
    touch '/usr/bin/paas-agent'

    # Remove the .pyc and .pyo files from the package and list them in a file
    # so that the prerm script knows which compiled files to remove
    command "echo '# DO NOT REMOVE/MODIFY - used by package removal tasks' > #{install_dir}/embedded/.py_compiled_files.txt"
    command "find #{install_dir}/embedded '(' -name '*.pyc' -o -name '*.pyo' ')' -type f -delete -print >> #{install_dir}/embedded/.py_compiled_files.txt"
  end

  if osx?
    env = {
      'PATH' => "#{install_dir}/embedded/bin/:#{ENV['PATH']}"
    }

    app_temp_dir = "#{install_dir}/agent/dist/paasinsight Agent.app/Contents"
    app_temp_dir_escaped = "#{install_dir}/agent/dist/paasinsight\\ Agent.app/Contents"
    pyside_build_dir =  "#{install_dir}/agent/build/bdist.macosx-10.5-intel/python2.7-standalone/app/collect/PySide"
    command_fix_shiboken = 'install_name_tool -change @rpath/libshiboken-python2.7.1.2.dylib'\
                      ' @executable_path/../Frameworks/libshiboken-python2.7.1.2.dylib '
    command_fix_pyside = 'install_name_tool -change @rpath/libpyside-python2.7.1.2.dylib'\
                      ' @executable_path/../Frameworks/libpyside-python2.7.1.2.dylib '

    # Command line tool
    copy '/root/paas-agent/packaging/osx/paas-agent', "#{install_dir}/bin"
    command "chmod 755 #{install_dir}/bin/paas-agent"

    # GUI
    copy '/root/paas-agent/packaging/paas-agent/win32/install_files/guidata/images', "#{install_dir}/agent"
    copy '/root/paas-agent/win32/gui.py', "#{install_dir}/agent"
    copy '/root/paas-agent/win32/status.html', "#{install_dir}/agent"
    mkdir "#{install_dir}/agent/packaging"
    copy '/root/paas-agent/packaging/osx/app/*', "#{install_dir}/agent/packaging"

    command "cd #{install_dir}/agent && "\
            "#{install_dir}/embedded/bin/python #{install_dir}/agent/setup.py py2app"\
            ' && cd -', env: env
    # Time to patch the install, see py2app bug: (dependencies to system PySide)
    # https://bitbucket.org/ronaldoussoren/py2app/issue/143/resulting-app-mistakenly-looks-for-pyside
    copy "#{pyside_build_dir}/libshiboken-python2.7.1.2.dylib", "#{app_temp_dir}/Frameworks/libshiboken-python2.7.1.2.dylib"
    copy "#{pyside_build_dir}/libpyside-python2.7.1.2.dylib", "#{app_temp_dir}/Frameworks/libpyside-python2.7.1.2.dylib"

    command "chmod a+x #{app_temp_dir_escaped}/Frameworks/{libpyside,libshiboken}-python2.7.1.2.dylib"
    command "#{command_fix_shiboken} #{app_temp_dir_escaped}/Frameworks/libpyside-python2.7.1.2.dylib"
    command 'install_name_tool -change /usr/local/lib/QtCore.framework/Versions/4/QtCore '\
            '@executable_path/../Frameworks/QtCore.framework/Versions/4/QtCore '\
            "#{app_temp_dir_escaped}/Frameworks/libpyside-python2.7.1.2.dylib"
    command "#{command_fix_shiboken} #{app_temp_dir_escaped}/Resources/lib/python2.7/lib-dynload/PySide/QtCore.so"
    command "#{command_fix_shiboken} #{app_temp_dir_escaped}/Resources/lib/python2.7/lib-dynload/PySide/QtGui.so"
    command "#{command_fix_pyside} #{app_temp_dir_escaped}/Resources/lib/python2.7/lib-dynload/PySide/QtCore.so"
    command "#{command_fix_pyside} #{app_temp_dir_escaped}/Resources/lib/python2.7/lib-dynload/PySide/QtGui.so"

    # And finally
    command "cp -Rf #{install_dir}/agent/dist/passinsight\\ Agent.app #{install_dir}"

    # Clean GUI related things
    %w(build dist images gui.py status.html packaging Paas_Agent.egg-info).each do |file|
        delete "#{install_dir}/agent/#{file}"
    end
    %w(py2app macholib modulegraph altgraph).each do |package|
        command "yes | #{install_dir}/embedded/bin/pip uninstall #{package}"
    end
    %w(pyside guidata spyderlib).each do |dependency_name|
      # Installed with `python setup.py install`, needs to be uninstalled manually
      command "cat #{install_dir}/embedded/#{dependency_name}-files.txt | xargs rm -rf \"{}\""
      delete "#{install_dir}/embedded/#{dependency_name}-files.txt"
    end

    # conf
    mkdir "#{install_dir}/etc"
    copy "packaging/osx/supervisor.conf", "#{install_dir}/etc/supervisor.conf"
    copy 'paasinsight.conf.example', "#{install_dir}/etc/paasinsight.conf.example"
    command "cp -R conf.d #{install_dir}/etc/"
    copy 'packaging/osx/com.paasinsight.Agent.plist.example', "#{install_dir}/etc/"
  end

  # The file below is touched by software builds that don't put anything in the installation
  # directory (libgcc right now) so that the git_cache gets updated let's remove it from the
  # final package
  delete "#{install_dir}/uselessfile"
end
