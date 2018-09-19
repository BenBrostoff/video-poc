using ReactNative.Bridge;
using System;
using System.Collections.Generic;
using Windows.ApplicationModel.Core;
using Windows.UI.Core;

namespace Video.Poc.RNVideoPoc
{
    /// <summary>
    /// A module that allows JS to share data.
    /// </summary>
    class RNVideoPocModule : NativeModuleBase
    {
        /// <summary>
        /// Instantiates the <see cref="RNVideoPocModule"/>.
        /// </summary>
        internal RNVideoPocModule()
        {

        }

        /// <summary>
        /// The name of the native module.
        /// </summary>
        public override string Name
        {
            get
            {
                return "RNVideoPoc";
            }
        }
    }
}
