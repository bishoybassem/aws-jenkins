import jenkins.model.Jenkins
import hudson.model.Computer
import hudson.model.Job
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.GlobalMatrixAuthorizationStrategy
import hudson.security.csrf.DefaultCrumbIssuer
import jenkins.security.s2m.AdminWhitelistRule
import java.util.regex.Matcher
import jenkins.model.JenkinsLocationConfiguration

def instance = Jenkins.getInstance()

if (instance.getSecurityRealm() == hudson.security.SecurityRealm.NO_AUTHENTICATION) {
    println '--> creating admin account'
    def securityRealm = new HudsonPrivateSecurityRealm(false)
    def jenkinsHome = System.getenv('JENKINS_HOME')
    securityRealm.createAccount('admin', 'ignore_as_it_will_be_modified_below')
    securityRealm.createAccount('slave', new File("$jenkinsHome/.slave_pass").text.trim())
    securityRealm.createAccount('monitoring', new File("$jenkinsHome/.monitoring_pass").text.trim())
    instance.setSecurityRealm(securityRealm)

    // Change the password for the admin user, by replacing the password hash in the config file. This is done
    // to avoid storing the admin's password in plain text on the instance (ex. this file or user-data).
    def jenkins_home = System.getenv('JENKINS_HOME')
    def adminConfig = new File(new FileNameFinder().getFileNames(jenkins_home, 'users/admin_*/config.xml')[0])
    def adminPassHash = new File("$jenkins_home/.admin_pass_hash").text.trim()
    adminConfig.text = adminConfig.text.replaceAll('<passwordHash>.*</passwordHash>',
            Matcher.quoteReplacement("<passwordHash>$adminPassHash</passwordHash>"))

    instance.reload()
}

if (instance.getAuthorizationStrategy() == hudson.security.AuthorizationStrategy.UNSECURED) {
    println '--> configuring permissions for admin account'
    def authStrategy = new GlobalMatrixAuthorizationStrategy()
    authStrategy.add(Jenkins.ADMINISTER, 'admin')
    authStrategy.add(Jenkins.READ, 'slave')
    authStrategy.add(Computer.CONFIGURE, 'slave')
    authStrategy.add(Computer.CONNECT, 'slave')
    authStrategy.add(Computer.CREATE, 'slave')
    authStrategy.add(Computer.DELETE, 'slave')
    authStrategy.add(Computer.DISCONNECT, 'slave')
    authStrategy.add(Jenkins.READ, 'monitoring')
    authStrategy.add(Job.DISCOVER, 'monitoring')
    instance.setAuthorizationStrategy(authStrategy)
}

if (!instance.getCrumbIssuer()) {
    println '--> enabling CSRF protection'
    instance.setCrumbIssuer(new DefaultCrumbIssuer(true))
}

println '--> enabling Agent → Master Access Control'
Jenkins.instance.getInjector().getInstance(AdminWhitelistRule.class)
        .setMasterKillSwitch(false)

println '--> disabling CLI over Remoting'
Jenkins.instance.getDescriptor('jenkins.CLI').get().setEnabled(false)

println '--> configuring url'
def jlc = JenkinsLocationConfiguration.get()
def publicHostName = new URL('http://169.254.169.254/latest/meta-data/public-hostname').getText()
jlc.setUrl("https://$publicHostName")

println "--> setting agent port for JNLP"
Jenkins.instance.setSlaveAgentPort(8081)