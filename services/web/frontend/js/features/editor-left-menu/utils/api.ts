import type {
  FontFamily,
  LineHeight,
  OverallTheme,
} from '../../../../../modules/source-editor/frontend/js/extensions/theme'
import type {
  Keybindings,
  PdfViewer,
  ProjectCompiler,
} from '../../../../../types/project-settings'
import { postJSON } from '../../../infrastructure/fetch-json'

export type UserSettings = {
  pdfViewer: PdfViewer
  autoComplete: boolean
  autoPairDelimiters: boolean
  syntaxValidation: boolean
  editorTheme: string
  overallTheme: OverallTheme
  mode: Keybindings
  fontSize: string
  fontFamily: FontFamily
  lineHeight: LineHeight
}

export type ProjectSettings = {
  compiler: ProjectCompiler
  imageName: string
  rootDocId: string
  spellCheckLanguage: string
}

type SaveUserSettings = Partial<
  UserSettings & {
    spellCheckLanguage: ProjectSettings['spellCheckLanguage']
  }
>

export function saveUserSettings(data: SaveUserSettings) {
  postJSON('/user/settings', {
    body: {
      ...data,
    },
  })
}

type SaveProjectSettings = {
  projectId: string
} & Partial<ProjectSettings>

export const saveProjectSettings = async ({
  projectId,
  ...data
}: SaveProjectSettings) => {
  await postJSON<never>(`/project/${projectId}/settings`, {
    body: {
      ...data,
    },
  })
}
