module DictionariesExt
import Skipper: filterview
import Dictionaries

filterview(f, X::Dictionaries.AbstractDictionary) = Dictionaries.filterview(f, X)

end
