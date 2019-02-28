import jenkins.model.Jenkins
import hudson.model.Computer
import hudson.security.HudsonPrivateSecurityRealm
import hudson.security.GlobalMatrixAuthorizationStrategy
import hudson.security.csrf.DefaultCrumbIssuer
import jenkins.security.s2m.AdminWhitelistRule
import jenkins.model.JenkinsLocationConfiguration

def instance = Jenkins.getInstance()

if (instance.getSecurityRealm() == hudson.security.SecurityRealm.NO_AUTHENTICATION) {
    println '--> creating admin and slave accounts'
    def securityRealm = new HudsonPrivateSecurityRealm(false)
    def jenkinsHome = System.getenv('JENKINS_HOME')
    securityRealm.createAccount('admin', new File("$jenkinsHome/.admin_pass").text.trim())
    securityRealm.createAccount('slave', new File("$jenkinsHome/.slave_pass").text.trim())
    instance.setSecurityRealm(securityRealm)
}

if (instance.getAuthorizationStrategy() == hudson.security.AuthorizationStrategy.UNSECURED) {
    println '--> configuring permissions for admin and slave accounts'
    def authStrategy = new GlobalMatrixAuthorizationStrategy()
    authStrategy.add(Jenkins.ADMINISTER, 'admin')
    authStrategy.add(Jenkins.READ , 'slave')
    authStrategy.add(Computer.CONFIGURE, 'slave')
    authStrategy.add(Computer.CONNECT, 'slave')
    authStrategy.add(Computer.CREATE, 'slave')
    authStrategy.add(Computer.DELETE, 'slave')
    authStrategy.add(Computer.DISCONNECT, 'slave')
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
JenkinsLocationConfiguration.get().setUrl("https://localhost")