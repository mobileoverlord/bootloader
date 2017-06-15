defmodule Bootloader.Plugin do
  use Mix.Releases.Plugin

  alias Bootloader.Utils
  alias Mix.Releases.{App, Release}
  alias Mix.Releases.Utils, as: ReleaseUtils

  def before_assembly(release), do: before_assembly(release, [])
  def before_assembly(release, _opts) do
    generate_boot_script(release)
    {bootloader, apps} =
      Enum.split_with(release.applications, & &1.name == :bootloader)
    apps =
      case bootloader do
        [bootloader] ->
          [%{bootloader | start_type: :none} | apps]
        _ -> apps
      end
    %{release | applications: apps}
  end

  def after_assembly(release), do: after_assembly(release, [])
  def after_assembly(%Release{} = release, _opts) do
    release
  end

  def before_package(release, _opts), do: release
  def after_package(release, _opts), do: release

  def generate_boot_script(app_release) do
    Application.load(:bootloader)
    runtime_spec = Application.spec(:bootloader)

    release = Release.new(:bootloader, runtime_spec[:vsn])
    release = %{release | profile: app_release.profile}

    release_apps = ReleaseUtils.get_apps(release)
    release = %{release | :applications => release_apps}
    rel_dir = Path.join(["#{app_release.profile.output_dir}", "releases", "#{release.version}"])

    erts_vsn =
    case app_release.profile.include_erts do
      bool when is_boolean(bool) ->
        Mix.Releases.Utils.erts_version()
      path ->
        {:ok, vsn} = Mix.Releases.Utils.detect_erts_version(path)
        vsn
    end

    start_apps = Enum.filter(app_release.applications, fn %App{name: n} ->
                               n in Utils.bootloader_applications end)
    load_apps = Enum.reject(app_release.applications,  fn %App{name: n} ->
                               n in Utils.bootloader_applications end)
    load_apps =
      #[]
      Enum.map(load_apps, & {&1.name, '#{&1.vsn}', :none})
    start_apps =
      Enum.map(start_apps, fn %App{name: name, vsn: vsn, start_type: start_type} ->
        case start_type do
          nil ->
            {name, '#{vsn}'}
          t ->
            {name, '#{vsn}', t}
        end
      end)
    relfile = {:release,
                    {'bootloader', '0.1.0'},
                    {:erts, '#{erts_vsn}'},
                    start_apps ++ load_apps}
    path = Path.join(rel_dir, "bootloader.rel")
    ReleaseUtils.write_term(path, relfile)

    erts_lib_dir =
      case release.profile.include_erts do
        false -> :code.lib_dir()
        true  -> :code.lib_dir()
        p     -> String.to_charlist(Path.expand(Path.join(p, "lib")))
      end

    options = [{:path, ['#{rel_dir}' | Release.get_code_paths(app_release)]},
               {:outdir, '#{rel_dir}'},
               {:variables, [{'ERTS_LIB_DIR', erts_lib_dir}]},
               :no_warn_sasl,
               :no_module_tests,
               :silent]

    :systools.make_script('bootloader', options)

    File.cp(Path.join(rel_dir, "bootloader.boot"),
                            Path.join([app_release.profile.output_dir, "bin", "bootloader.boot"]))
  end

  defp filter_app_list(apps) do
    {_, apps} =
      Enum.split_with(apps, & &1 == :bootloader)
      apps
  end
end
