/**
 * Type-only shim for `@opencode-ai/plugin` used when the workspace is not
 * fully installed (i.e. running tests from a standalone checkout of
 * `packages/omnicoder`). At runtime nothing from `@opencode-ai/plugin` is
 * imported — hooks use structural typing only.
 *
 * When the real peerDep is resolved through the bun workspace, the proper
 * types from `packages/plugin/src/index.ts` take precedence because they
 * appear on the module resolution path first.
 */
declare module "@opencode-ai/plugin" {
  export type PluginInput = {
    client: unknown
    project: unknown
    directory: string
    worktree: string
    experimental_workspace: { register: (type: string, adaptor: unknown) => void }
    serverUrl: URL
    $: unknown
  }

  export type PluginOptions = Record<string, unknown>

  export type Hooks = Record<string, unknown>

  export type Plugin = (input: PluginInput, options?: PluginOptions) => Promise<Hooks>

  export type PluginModule = {
    id?: string
    server: Plugin
    tui?: never
  }

  export type ProviderContext = {
    source: "env" | "config" | "custom" | "api"
    info: { id: string; name?: string }
    options: Record<string, unknown>
  }
}

declare module "@opencode-ai/sdk" {
  export type Event = { type: string; properties?: Record<string, unknown> }
  export type Model = { providerID: string; modelID: string }
  export type UserMessage = { id?: string; role?: string }
  export type Message = UserMessage
  export type Part = { type: string; text?: string }
  export type Provider = { id: string; name?: string }
  export type Project = { id: string }
  export type Auth = Record<string, unknown>
  export type Config = Record<string, unknown>
  export type Permission = Record<string, unknown>
  export function createOpencodeClient(_input?: unknown): unknown
}

declare module "@opencode-ai/sdk/v2" {
  export type Provider = { id: string }
  export type Model = { providerID: string; modelID: string }
}
