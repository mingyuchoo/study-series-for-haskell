module Todo.Application.Form
  ( emptyForm
  , formFromTodo
  , updateField
  , advanceFocus
  , formFields
  ) where

import Data.Maybe (fromMaybe)
import Todo.Application.Types
import Todo.Domain.Model qualified as Domain

emptyForm :: Form
emptyForm = Form "" "" "" "" FocusAction

formFromTodo :: Domain.Todo -> Form
formFromTodo todo =
  let value = Domain.fields todo
   in Form
        (Domain.action value)
        (fromMaybe "" $ Domain.subject value)
        (fromMaybe "" $ Domain.indirectObject value)
        (fromMaybe "" $ Domain.directObject value)
        FocusAction

updateField :: FocusedField -> String -> Form -> Form
updateField FocusAction value form = form {formAction = value}
updateField FocusSubject value form = form {formSubject = value}
updateField FocusIndirectObject value form = form {formIndirectObject = value}
updateField FocusDirectObject value form = form {formDirectObject = value}

advanceFocus :: Form -> Form
advanceFocus form = form {formFocus = next $ formFocus form}
  where
    next FocusAction = FocusSubject
    next FocusSubject = FocusIndirectObject
    next FocusIndirectObject = FocusDirectObject
    next FocusDirectObject = FocusAction

formFields :: Form -> Either Domain.ValidationError Domain.TodoFields
formFields form =
  Domain.validateFields
    (formAction form)
    (Just $ formSubject form)
    (Just $ formIndirectObject form)
    (Just $ formDirectObject form)
