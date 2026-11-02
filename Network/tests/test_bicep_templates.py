import json
import os
from pathlib import Path
import secrets
import subprocess
import unittest


HANDSON = Path(__file__).resolve().parents[1] / "ハンズオン"
LAB_BICEP_DIRS = {
    "lab_01": HANDSON / "Lab_01" / "bicep",
    "lab_02": HANDSON / "Lab_02" / "bicep",
    "lab_03": HANDSON / "Lab_03" / "bicep",
}


def build(exercise):
    result = subprocess.run(
        ["bicep", "build", str(LAB_BICEP_DIRS[exercise] / "main.bicep"), "--stdout"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        check=True,
    )
    if result.stderr.strip():
        raise AssertionError(result.stderr)
    return json.loads(result.stdout)


class BicepTemplatesTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.initial = build("lab_01")
        cls.troubleshooting = build("lab_03")
        cls.bgp_demo = build("lab_02")

    def resource(self, name):
        return next(r for r in self.troubleshooting["resources"] if r["name"] == name)

    def test_initial_environment_still_has_no_peering_or_routes(self):
        types = {r["type"] for r in self.initial["resources"]}
        self.assertNotIn("Microsoft.Network/routeTables", types)
        self.assertNotIn("Microsoft.Network/virtualNetworks/virtualNetworkPeerings", types)
        network = next(
            r for r in self.initial["resources"] if r["type"] == "Microsoft.Resources/deployments"
        )["properties"]["template"]
        vnet = next(r for r in network["resources"] if r["type"] == "Microsoft.Network/virtualNetworks")
        self.assertIn("'defaultOutboundAccess', false()", vnet["properties"]["subnets"])
        self.assertEqual(self.initial["parameters"]["adminPassword"]["type"], "securestring")

    def test_both_faults_are_present_in_default_template(self):
        routes = self.resource("rt-spoke2")["properties"]["routes"]
        self.assertEqual(routes, [], "Explicit empty array must replace existing return routes")
        groups = [r for r in self.troubleshooting["resources"] if r["type"].endswith("/ruleCollectionGroups")]
        self.assertEqual(len(groups), 1)
        collections = groups[0]["properties"]["ruleCollections"]
        self.assertEqual(len(collections), 2)
        https = next(c for c in collections if c["name"] == "allow-lab-https")
        self.assertEqual(https["action"]["type"], "Allow")
        rule = https["rules"][0]
        self.assertEqual(rule["sourceAddresses"], ["10.1.1.4"])
        self.assertEqual(rule["protocols"], [{"protocolType": "Https", "port": 443}])
        self.assertEqual(rule["targetFqdns"], ["www.example.com"])
        self.assertEqual(self.troubleshooting["outputs"]["targetUrl"]["value"], "https://www.microsoft.com/")
        icmp = next(c for c in collections if c["name"] == "allow-lab-icmp")["rules"][0]
        self.assertEqual(icmp["ipProtocols"], ["ICMP"])
        self.assertEqual(icmp["sourceAddresses"], ["10.0.2.4", "10.1.1.4", "10.2.1.4"])
        self.assertEqual(icmp["destinationAddresses"], icmp["sourceAddresses"])

    def test_forward_and_internet_routes_remain_correct(self):
        routes = self.resource("rt-spoke1")["properties"]["routes"]
        self.assertEqual(
            {r["properties"]["addressPrefix"] for r in routes}, {"10.2.0.0/16", "0.0.0.0/0"}
        )
        for route in routes:
            self.assertEqual(route["properties"]["nextHopType"], "VirtualAppliance")
            self.assertEqual(
                route["properties"]["nextHopIpAddress"],
                self.troubleshooting["outputs"]["firewallPrivateIp"]["value"],
            )

    def test_existing_infrastructure_is_not_recreated(self):
        allowed_types = {
            "Microsoft.Network/routeTables",
            "Microsoft.Network/virtualNetworks/subnets",
            "Microsoft.Network/virtualNetworks/virtualNetworkPeerings",
            "Microsoft.Network/firewallPolicies/ruleCollectionGroups",
        }
        resources = self.troubleshooting["resources"]
        self.assertEqual(len(resources), 9)
        self.assertEqual({r["type"] for r in resources}, allowed_types)
        subnets = [r for r in resources if r["type"].endswith("/subnets")]
        self.assertEqual(len(subnets), 2)
        for subnet in subnets:
            props = subnet["properties"]
            self.assertFalse(props["defaultOutboundAccess"])
            self.assertIn("networkSecurityGroup", props)
            self.assertIn("routeTable", props)
        peerings = [r for r in resources if r["type"].endswith("/virtualNetworkPeerings")]
        self.assertEqual(len(peerings), 4)
        for peering in peerings:
            self.assertTrue(peering["properties"]["allowForwardedTraffic"])
            self.assertTrue(peering["properties"]["allowVirtualNetworkAccess"])
            self.assertFalse(peering["properties"]["useRemoteGateways"])

    def test_bgp_demo_has_isolated_vnets_gateways_and_bidirectional_bgp(self):
        resources = self.bgp_demo["resources"]
        vnets = [r for r in resources if r["type"] == "Microsoft.Network/virtualNetworks"]
        gateways = [r for r in resources if r["type"] == "Microsoft.Network/virtualNetworkGateways"]
        connections = [r for r in resources if r["type"] == "Microsoft.Network/connections"]
        peerings = [
            r for r in resources
            if r["type"] == "Microsoft.Network/virtualNetworks/virtualNetworkPeerings"
        ]
        self.assertEqual(len(vnets), 3)
        self.assertEqual(len(gateways), 2)
        self.assertEqual(len(connections), 2)
        self.assertEqual(
            self.bgp_demo["parameters"]["hubAsn"]["defaultValue"], 65010
        )
        self.assertEqual(
            self.bgp_demo["parameters"]["onPremAsn"]["defaultValue"], 65020
        )
        self.assertTrue(all(r["properties"]["enableBgp"] for r in connections))
        self.assertEqual(len(peerings), 2)
        self.assertTrue(all(p["properties"]["allowForwardedTraffic"] for p in peerings))
        self.assertEqual(
            {p["properties"].get("allowGatewayTransit", False) for p in peerings},
            {False, True},
        )
        self.assertEqual(
            {p["properties"].get("useRemoteGateways", False) for p in peerings},
            {False, True},
        )

    def test_bgp_demo_keeps_vms_private_and_propagates_gateway_routes(self):
        resources = self.bgp_demo["resources"]
        route_table = next(
            r for r in resources
            if r["type"] == "Microsoft.Network/routeTables"
        )
        self.assertFalse(route_table["properties"]["disableBgpRoutePropagation"])
        self.assertEqual(route_table["properties"]["routes"], [])
        subnets = [r for r in resources if r["type"] == "Microsoft.Network/virtualNetworks/subnets"]
        gateway_subnets = [r for r in subnets if "GatewaySubnet" in r["name"]]
        self.assertEqual(len(gateway_subnets), 2)
        self.assertTrue(
            all("networkSecurityGroup" not in r["properties"] for r in gateway_subnets)
        )
        vms = [r for r in resources if r["type"] == "Microsoft.Compute/virtualMachines"]
        self.assertEqual(len(vms), 1)
        self.assertEqual(vms[0]["copy"]["count"], "[length(variables('vmNodes'))]")
        self.assertTrue(
            all("publicIPAddress" not in str(r["properties"]["networkProfile"]) for r in vms)
        )
        bastions = [r for r in resources if r["type"] == "Microsoft.Network/bastionHosts"]
        self.assertEqual(len(bastions), 2)
        self.assertTrue(all(r["sku"]["name"] == "Developer" for r in bastions))
        self.assertEqual(self.bgp_demo["parameters"]["adminPassword"]["type"], "securestring")
        self.assertEqual(self.bgp_demo["parameters"]["vpnSharedKey"]["type"], "securestring")

    def test_parameter_files_compile(self):
        env = dict(
            os.environ,
            NW_LAB_ADMIN_PASSWORD=secrets.token_urlsafe(24),
            NW_BGP_ADMIN_PASSWORD=secrets.token_urlsafe(24),
            NW_BGP_VPN_SHARED_KEY=secrets.token_urlsafe(24),
        )
        for exercise in (
            "lab_01",
            "lab_03",
            "lab_02",
        ):
            result = subprocess.run(
                [
                    "bicep",
                    "build-params",
                    str(LAB_BICEP_DIRS[exercise] / "main.bicepparam"),
                    "--stdout",
                ],
                env=env,
                capture_output=True,
                text=True,
                encoding="utf-8",
                check=True,
            )
            self.assertFalse(result.stderr.strip(), result.stderr)
            self.assertIsInstance(json.loads(result.stdout), dict)


if __name__ == "__main__":
    unittest.main()
