import hudson.model.JDK
import hudson.tools.InstallSourceProperty
import hudson.tools.ZipExtractionInstaller

def descriptor = new JDK.DescriptorImpl();


def List<JDK> installations = []

javaTools=[['name':'jdk8', 'url':'file:/tmp/jdk-8u162-linux-x64.tar.gz', 'subdir':'jdk1.8u162'],
      ['name':'jdk9', 'url':'file:/tmp/jdk-9.0.4_linux-x64_bin.tar.gz', 'subdir':'jdk1.9.0.4']]

javaTools.each { javaTool ->

    println("Setting up tool: ${javaTool.name}")

    def installer = new ZipExtractionInstaller(javaTool.label as String, javaTool.url as String, javaTool.subdir as String);
    def jdk = new JDK(javaTool.name as String, null, [new InstallSourceProperty([installer])])
    installations.add(jdk)

}
descriptor.setInstallations(installations.toArray(new JDK[installations.size()]))
descriptor.save()
