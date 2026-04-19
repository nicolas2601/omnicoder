/**
 * @omnicoder/core — Opencode plugin that bundles OmniCoder capabilities.
 *
 * Registers:
 *   - skill-router         (experimental.chat.system.transform)
 *   - security-guard       (tool.execute.before)
 *   - memory-loader        (experimental.chat.system.transform)
 *   - token-budget         (event)
 *   - tool-dispatcher      (tool.execute.after)
 *   - provider-failover    (chat.params)
 *
 * Marker: // OMNICODER: — used for upstream merge safety.
 */
import type { Plugin, PluginInput } from "@opencode-ai/plugin"
import { createSkillRouter } from "./router/index.js"
import { createSecurityGuard } from "./security/index.js"
import { createMemoryLoader } from "./memory/index.js"
import { createTokenBudget } from "./budget/index.js"
import { createToolDispatcher } from "./hooks/tool-dispatcher.js"
import { createProviderFailover } from "./hooks/provider-failover.js"
import { createPersonalityLoader } from "./personality/index.js"

export const OmnicoderPlugin: Plugin = async (input: PluginInput) => {
  const router = await createSkillRouter(input)
  const guard = await createSecurityGuard(input)
  const memory = await createMemoryLoader(input)
  const budget = await createTokenBudget(input)
  const dispatcher = await createToolDispatcher(input)
  const failover = await createProviderFailover(input)
  const personality = createPersonalityLoader()

  return {
    async "experimental.chat.system.transform"(i: any, o: any) {
      await personality.inject(i, o)
      await memory.inject(i, o)
      await router.inject(i, o)
    },
    async "tool.execute.before"(i: any, o: any) {
      await guard.check(i, o)
    },
    async "tool.execute.after"(i: any, o: any) {
      await dispatcher.onComplete(i, o)
    },
    async "chat.params"(i: any, o: any) {
      await failover.tune(i, o)
    },
    async event({ event }: { event: any }) {
      await budget.onEvent(event)
      await dispatcher.onEvent(event)
    },
  }
}

export default { server: OmnicoderPlugin, id: "@omnicoder/core" }
